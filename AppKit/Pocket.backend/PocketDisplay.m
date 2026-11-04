/* AppKit's Pocket backend: the display of a phone host.

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import "PocketDisplay.h"
#import "PocketWindow.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSText.h>
#import <AppKit/NSTouch.h>
#import <AppKit/NSWindow.h>
#import <CoreFoundation/CFSocket.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <errno.h>
#include <pthread.h>
#include <fcntl.h>
#include <poll.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

// The host's screen: its scale, and the edges it covers.
@interface PocketScreen : NSScreen {
@public
    CGFloat _scale;
    NSEdgeInsets _safeArea;
}
@end

@implementation PocketScreen
- (CGFloat) backingScaleFactor { return _scale; }
- (NSEdgeInsets) safeAreaInsets { return _safeArea; }
@end

// The host has no clipboard to share yet, so a pasteboard lives in the
// process.
@interface PocketPasteboard : NSPasteboard {
    NSString *_name;
    NSMutableDictionary *_data;
    NSMutableArray *_types;
    NSInteger _changeCount;
}
- (instancetype) initWithName: (NSString *) name;
@end

@implementation PocketPasteboard

- (instancetype) initWithName: (NSString *) name {
    if ((self = [super init]) != nil) {
        _name = [name copy];
        _data = [NSMutableDictionary new];
        _types = [NSMutableArray new];
    }
    return self;
}

- (void) dealloc {
    [_name release];
    [_data release];
    [_types release];
    [super dealloc];
}

- (NSPasteboardName) name { return _name; }
- (NSInteger) changeCount { return _changeCount; }
- (oneway void) releaseGlobally {}
- (NSArray *) types { return [[_types copy] autorelease]; }

- (NSInteger) clearContents {
    [_data removeAllObjects];
    [_types removeAllObjects];
    return ++_changeCount;
}

- (NSInteger) declareTypes: (NSArray *) types owner: (id) owner {
    [self clearContents];
    return [self addTypes: types owner: owner];
}

- (NSInteger) addTypes: (NSArray *) types owner: (id) owner {
    for (NSString *type in types)
        if (![_types containsObject: type])
            [_types addObject: type];
    return _changeCount;
}

- (BOOL) setData: (NSData *) data forType: (NSPasteboardType) type {
    if (![_types containsObject: type])
        [_types addObject: type];
    if (data != nil)
        [_data setObject: [[data copy] autorelease] forKey: type];
    else
        [_data removeObjectForKey: type];
    return YES;
}

- (NSData *) dataForType: (NSPasteboardType) type {
    return [_data objectForKey: type];
}

@end

static void socketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    [(PocketDisplay *) info processPendingEvents];
}

static NSString *stringFromBytes(const uint8_t *bytes, size_t length) {
    NSString *string = [[NSString alloc] initWithBytes: bytes length: length encoding: NSUTF8StringEncoding];
    return [string autorelease];
}

@implementation PocketDisplay

- (instancetype) init {
    // Before any early release: -dealloc closes the socket, and descriptor 0 is not ours.
    _socket = -1;
    const char *path = getenv("DARLING_POCKET_DISPLAY");
    if (path == NULL || *path == '\0') {
        [self release];
        return nil;
    }

    // Skip -[X11Display init], which connects to an X server.
    struct objc_super superInfo = {self, [NSDisplay class]};
    self = ((id (*)(struct objc_super *, SEL)) objc_msgSendSuper)(&superInfo, _cmd);
    if (self == nil)
        return nil;

    _windows = CFArrayCreateMutable(NULL, 0, NULL);
    _pasteboards = [NSMutableDictionary new];
    // X11Display's: click counting needs a real dictionary.
    _buttonClickCounts = [NSMutableDictionary new];

    struct sockaddr_un address = {.sun_family = AF_UNIX};
    if (strlen(path) >= sizeof(address.sun_path)) {
        NSLog(@"Pocket backend: the socket path %s is too long", path);
        [self release];
        return nil;
    }
    strcpy(address.sun_path, path);
    _socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (_socket < 0 || connect(_socket, (struct sockaddr *) &address, sizeof(address)) != 0) {
        NSLog(@"Pocket backend: cannot connect to the host at %s: %s, trying the next backend", path,
              strerror(errno));
        [self release];
        return nil;
    }
    fcntl(_socket, F_SETFD, FD_CLOEXEC);

    struct pocket_hello hello = {POCKET_PROTOCOL_VERSION, (uint32_t) getpid()};
    [self send: POCKET_HELLO bytes: &hello length: sizeof(hello)];

    // Windows are placed on the screen, so it must be known first.
    for (int waited = 0; !_haveScreen && waited < 100; waited++) {
        struct pollfd pfd = {.fd = _socket, .events = POLLIN};
        if (poll(&pfd, 1, 100) > 0 && ![self readMessages])
            break;
    }
    if (!_haveScreen) {
        NSLog(@"Pocket backend: the host at %s did not describe its screen", path);
        [self release];
        return nil;
    }
    fcntl(_socket, F_SETFL, fcntl(_socket, F_GETFL) | O_NONBLOCK);
    _nonblocking = YES;

    CFSocketContext context = {.version = 0, .info = self};
    _pocketSocket = CFSocketCreateWithNative(NULL, _socket, kCFSocketReadCallBack, socketCallback, &context);
    CFSocketSetSocketFlags(_pocketSocket, CFSocketGetSocketFlags(_pocketSocket) & ~kCFSocketCloseOnInvalidate);
    _pocketSource = CFSocketCreateRunLoopSource(NULL, _pocketSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), _pocketSource, kCFRunLoopCommonModes);

    NSLog(@"Pocket backend: connected to %s, screen %ux%u at %.2fx", path, _screen.width, _screen.height,
          [self scale]);
    return self;
}

- (void) dealloc {
    if (_pocketSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _pocketSource, kCFRunLoopCommonModes);
        CFRelease(_pocketSource);
    }
    if (_pocketSocket != NULL) {
        CFSocketInvalidate(_pocketSocket);
        CFRelease(_pocketSocket);
    }
    if (_socket >= 0)
        close(_socket);
    if (_windows != NULL)
        CFRelease(_windows);
    [_screens release];
    [_pasteboards release];
    [super dealloc];
}

#pragma mark - The connection

- (void) hostGone {
    NSLog(@"Pocket backend: lost the connection to the host");
    exit(1);
}

- (void) writeAll: (const uint8_t *) bytes length: (size_t) length {
    while (length > 0) {
        ssize_t sent = send(_socket, bytes, length, 0);
        if (sent < 0 && (errno == EAGAIN || errno == EINTR)) {
            struct pollfd pfd = {.fd = _socket, .events = POLLOUT};
            poll(&pfd, 1, 1000);
            continue;
        }
        if (sent <= 0)
            [self hostGone];
        bytes += sent;
        length -= sent;
    }
}

- (void) send: (uint32_t) type bytes: (const void *) bytes length: (size_t) length {
    [self send: type bytes: bytes length: length fd: -1];
}

// Windows may present from a queue of their own (-[PocketWindow
// flushBufferAsync]): one message at a time goes on the socket.
static pthread_mutex_t sendLock = PTHREAD_MUTEX_INITIALIZER;

- (void) send: (uint32_t) type bytes: (const void *) bytes length: (size_t) length fd: (int) fd {
    pthread_mutex_lock(&sendLock);
    [self lockedSend: type bytes: bytes length: length fd: fd];
    pthread_mutex_unlock(&sendLock);
}

- (void) lockedSend: (uint32_t) type bytes: (const void *) bytes length: (size_t) length fd: (int) fd {
    if (_socket < 0)
        return;
    uint8_t message[sizeof(struct pocket_header) + POCKET_MAX_MESSAGE];
    if (length > POCKET_MAX_MESSAGE)
        return;
    struct pocket_header header = {type, (uint32_t) length};
    memcpy(message, &header, sizeof(header));
    memcpy(message + sizeof(header), bytes, length);
    size_t total = sizeof(header) + length;

    if (fd < 0) {
        [self writeAll: message length: total];
        return;
    }

    // The descriptor goes with the first byte; the rest follows as usual.
    union {
        struct cmsghdr header;
        char space[CMSG_SPACE(sizeof(int))];
    } control;
    memset(&control, 0, sizeof(control));
    struct iovec iov = {.iov_base = message, .iov_len = total};
    struct msghdr msg = {
        .msg_iov = &iov,
        .msg_iovlen = 1,
        .msg_control = control.space,
        .msg_controllen = sizeof(control.space),
    };
    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(cmsg), &fd, sizeof(int));

    ssize_t sent;
    do {
        sent = sendmsg(_socket, &msg, 0);
        if (sent < 0 && errno == EAGAIN) {
            struct pollfd pfd = {.fd = _socket, .events = POLLOUT};
            poll(&pfd, 1, 1000);
        }
    } while (sent < 0 && (errno == EAGAIN || errno == EINTR));
    if (sent <= 0)
        [self hostGone];
    if ((size_t) sent < total)
        [self writeAll: message + sent length: total - sent];
}

// Whether the touch move at offset is superseded by a later move of the same
// finger that has arrived too, before any other kind of message: an app that
// draws slower than the touch screen reports would otherwise fall ever
// further behind the finger.
- (BOOL) touchMoveIsStale: (size_t) offset {
    struct pocket_header header;
    struct pocket_touch touch, later;
    memcpy(&header, _input + offset, sizeof(header));
    if (header.type != POCKET_TOUCH || header.size < sizeof(touch))
        return NO;
    memcpy(&touch, _input + offset + sizeof(header), sizeof(touch));
    if (touch.phase != POCKET_TOUCH_MOVED)
        return NO;
    for (offset += sizeof(header) + header.size;
         _inputLength - offset >= sizeof(header); offset += sizeof(header) + header.size) {
        memcpy(&header, _input + offset, sizeof(header));
        if (header.size > POCKET_MAX_MESSAGE || _inputLength - offset < sizeof(header) + header.size)
            return NO;
        if (header.type != POCKET_TOUCH || header.size < sizeof(later))
            return NO;
        memcpy(&later, _input + offset + sizeof(header), sizeof(later));
        if (later.phase != POCKET_TOUCH_MOVED)
            return NO;
        if (later.finger == touch.finger)
            return YES;
    }
    return NO;
}

// Reads what has arrived and handles each whole message. NO when the host
// closed the connection.
- (BOOL) readMessages {
    for (;;) {
        ssize_t got = recv(_socket, _input + _inputLength, sizeof(_input) - _inputLength, 0);
        if (got < 0 && errno == EINTR)
            continue;
        if (got < 0 && errno == EAGAIN)
            return YES;
        if (got <= 0)
            return NO;
        _inputLength += got;

        size_t offset = 0;
        while (_inputLength - offset >= sizeof(struct pocket_header)) {
            struct pocket_header header;
            memcpy(&header, _input + offset, sizeof(header));
            if (header.size > POCKET_MAX_MESSAGE)
                return NO;
            if (_inputLength - offset < sizeof(header) + header.size)
                break;
            if (![self touchMoveIsStale: offset])
                [self handleMessage: header.type
                              bytes: _input + offset + sizeof(header)
                             length: header.size];
            offset += sizeof(header) + header.size;
        }
        memmove(_input, _input + offset, _inputLength - offset);
        _inputLength -= offset;

        // Before the connection is non-blocking (waiting for the screen),
        // one read at a time.
        if (!_nonblocking)
            return YES;
    }
}

- (void) processPendingEvents {
    if (_socket >= 0 && ![self readMessages])
        [self hostGone];
}

- (NSEvent *) nextEventMatchingMask: (NSEventMask) mask
                          untilDate: (NSDate *) untilDate
                             inMode: (NSRunLoopMode) mode
                            dequeue: (BOOL) dequeue
{
    [self processPendingEvents];
    // NSDisplay's queue handling, without X11Display's X event processing.
    struct objc_super superInfo = {self, [NSDisplay class]};
    return ((NSEvent * (*) (struct objc_super *, SEL, NSEventMask, NSDate *, NSRunLoopMode, BOOL))
                    objc_msgSendSuper)(&superInfo, _cmd, mask, untilDate, mode, dequeue);
}

#pragma mark - Messages from the host

- (PocketWindow *) windowWithNumber: (uint32_t) number {
    for (CFIndex i = 0; i < CFArrayGetCount(_windows); i++) {
        PocketWindow *window = (PocketWindow *) CFArrayGetValueAtIndex(_windows, i);
        if ([window number] == number)
            return window;
    }
    return nil;
}

- (void) handleMessage: (uint32_t) type bytes: (const uint8_t *) bytes length: (size_t) length {
    switch (type) {
    case POCKET_SCREEN:
        if (length >= sizeof(struct pocket_screen)) {
            struct pocket_screen screen;
            memcpy(&screen, bytes, sizeof(screen));
            [self screenChanged: screen];
        }
        break;
    case POCKET_RELEASE:
        if (length >= sizeof(struct pocket_window_id)) {
            struct pocket_window_id message;
            memcpy(&message, bytes, sizeof(message));
            [[self windowWithNumber: message.window] bufferReleased];
        }
        break;
    case POCKET_TOUCH:
        if (length >= sizeof(struct pocket_touch)) {
            struct pocket_touch touch;
            memcpy(&touch, bytes, sizeof(touch));
            [self touch: touch];
        }
        break;
    case POCKET_KEY:
        if (length >= sizeof(struct pocket_key)) {
            struct pocket_key key;
            memcpy(&key, bytes, sizeof(key));
            if (key.length <= length - sizeof(key))
                [self key: key characters: stringFromBytes(bytes + sizeof(key), key.length)];
        }
        break;
    case POCKET_TEXT:
        [self commitText: stringFromBytes(bytes, length)];
        break;
    case POCKET_KEYBOARD_FRAME:
        if (length >= sizeof(struct pocket_keyboard_frame)) {
            struct pocket_keyboard_frame frame;
            memcpy(&frame, bytes, sizeof(frame));
            [self keyboardFrameChanged: frame];
        }
        break;
    default:
        break;
    }
}

- (void) screenChanged: (struct pocket_screen) screen {
    if (screen.width == 0 || screen.height == 0)
        return;
    if (screen.scale_milli == 0)
        screen.scale_milli = 1000;
    BOOL changed = _haveScreen && memcmp(&screen, &_screen, sizeof(screen)) != 0;
    _screen = screen;
    _haveScreen = YES;
    [_screens release];
    _screens = nil;
    if (!changed)
        return;
    for (CFIndex i = 0; i < CFArrayGetCount(_windows); i++)
        [(PocketWindow *) CFArrayGetValueAtIndex(_windows, i) screenChanged];
    [[NSNotificationCenter defaultCenter] postNotificationName: NSApplicationDidChangeScreenParametersNotification
                                                        object: NSApp];
}

// The topmost visible window under a point of the screen, in points.
- (PocketWindow *) windowAtPoint: (NSPoint) point {
    PocketWindow *found = nil;
    for (CFIndex i = 0; i < CFArrayGetCount(_windows); i++) {
        PocketWindow *window = (PocketWindow *) CFArrayGetValueAtIndex(_windows, i);
        if ([window isVisible] && NSPointInRect(point, [window frame]) &&
            (found == nil || [window level] >= [found level]))
            found = window;
    }
    return found;
}

- (void) touch: (struct pocket_touch) touch {
    static NSMutableDictionary *windowsByFinger;
    if (windowsByFinger == nil)
        windowsByFinger = [NSMutableDictionary new];

    CGFloat scale = [self scale];
    NSPoint point = NSMakePoint(touch.x / scale, NSMaxY([self screenFrame]) - touch.y / scale);
    NSNumber *finger = [NSNumber numberWithUnsignedInt: touch.finger];
    PocketWindow *window;
    NSTouchPhase phase;
    switch (touch.phase) {
    case POCKET_TOUCH_BEGAN:
        phase = NSTouchPhaseBegan;
        window = [self windowAtPoint: point];
        if (window != nil)
            [windowsByFinger setObject: [NSNumber numberWithUnsignedInt: [window number]] forKey: finger];
        break;
    case POCKET_TOUCH_MOVED:
        phase = NSTouchPhaseMoved;
        window = [self windowWithNumber: [[windowsByFinger objectForKey: finger] unsignedIntValue]];
        break;
    case POCKET_TOUCH_ENDED:
    case POCKET_TOUCH_CANCELLED:
    default:
        phase = touch.phase == POCKET_TOUCH_ENDED ? NSTouchPhaseEnded : NSTouchPhaseCancelled;
        window = [self windowWithNumber: [[windowsByFinger objectForKey: finger] unsignedIntValue]];
        [windowsByFinger removeObjectForKey: finger];
        break;
    }
    _lastTouch = point;
    if (window == nil || [window delegate] == nil)
        return;
    NSRect frame = [window frame];
    NSTouchPost([window delegate], touch.finger, phase,
                NSMakePoint(point.x - frame.origin.x, point.y - frame.origin.y), touch.time);
}

- (NSWindow *) keyWindow {
    NSWindow *window = [NSApp keyWindow];
    if (window == nil) {
        for (CFIndex i = CFArrayGetCount(_windows) - 1; i >= 0 && window == nil; i--) {
            PocketWindow *platform = (PocketWindow *) CFArrayGetValueAtIndex(_windows, i);
            if ([platform isVisible])
                window = [platform delegate];
        }
    }
    return window;
}

- (void) postKey: (BOOL) down
         keyCode: (unsigned short) keyCode
       modifiers: (NSEventModifierFlags) modifiers
      characters: (NSString *) characters
{
    NSWindow *window = [self keyWindow];
    if (window == nil)
        return;
    NSEvent *event = [NSEvent keyEventWithType: down ? NSKeyDown : NSKeyUp
                                      location: NSZeroPoint
                                 modifierFlags: modifiers
                                     timestamp: [NSDate timeIntervalSinceReferenceDate]
                                  windowNumber: [window windowNumber]
                                       context: nil
                                    characters: characters
                   charactersIgnoringModifiers: characters
                                     isARepeat: NO
                                       keyCode: keyCode];
    [self postEvent: event atStart: NO];
}

// The characters AppKit's key bindings expect from the keys that type none
// (StandardKeyBindings: Delete is a backspace here, not macOS's 0x7f).
static NSString *charactersForSpecialKey(uint32_t keycode) {
    unichar character;
    switch (keycode) {
    case 36: character = '\r'; break;   // kVK_Return
    case 76: character = 0x03; break;   // kVK_ANSI_KeypadEnter
    case 48: character = '\t'; break;   // kVK_Tab
    case 51: character = 0x08; break;   // kVK_Delete
    case 53: character = 0x1B; break;   // kVK_Escape
    case 117: character = NSDeleteFunctionKey; break;
    case 115: character = NSHomeFunctionKey; break;
    case 119: character = NSEndFunctionKey; break;
    case 116: character = NSPageUpFunctionKey; break;
    case 121: character = NSPageDownFunctionKey; break;
    case 123: character = NSLeftArrowFunctionKey; break;
    case 124: character = NSRightArrowFunctionKey; break;
    case 125: character = NSDownArrowFunctionKey; break;
    case 126: character = NSUpArrowFunctionKey; break;
    default: return nil;
    }
    return [NSString stringWithCharacters: &character length: 1];
}

- (void) key: (struct pocket_key) key characters: (NSString *) characters {
    _modifierFlags = key.modifiers;
    NSString *special = charactersForSpecialKey(key.keycode);
    if (special != nil)
        characters = special;
    [self postKey: key.down != 0
          keyCode: key.keycode == 0xFFFF ? 0 : (unsigned short) key.keycode
        modifiers: key.modifiers
       characters: characters ? characters : @""];
}

// An input method's text, as a key typing it.
- (void) commitText: (NSString *) text {
    if ([text length] == 0)
        return;
    [self postKey: YES keyCode: 0 modifiers: 0 characters: text];
    [self postKey: NO keyCode: 0 modifiers: 0 characters: text];
}

#pragma mark - Windows

- (CGWindow *) newWindowWithDelegate: (NSWindow *) delegate {
    return [[PocketWindow alloc] initWithDelegate: delegate];
}

- (void) sendOrder {
    CFIndex count = CFArrayGetCount(_windows);
    uint32_t numbers[POCKET_MAX_MESSAGE / sizeof(uint32_t)];
    CFIndex sent = 0;
    // By level, then in the order they were raised.
    NSMutableArray *sorted = [NSMutableArray arrayWithCapacity: count];
    for (CFIndex i = 0; i < count; i++)
        [sorted addObject: (id) CFArrayGetValueAtIndex(_windows, i)];
    [sorted sortWithOptions: NSSortStable
            usingComparator: ^NSComparisonResult(PocketWindow *a, PocketWindow *b) {
                return [a level] < [b level] ? NSOrderedAscending
                                             : [a level] > [b level] ? NSOrderedDescending : NSOrderedSame;
            }];
    for (PocketWindow *window in sorted)
        if (sent < (CFIndex) (sizeof(numbers) / sizeof(numbers[0])))
            numbers[sent++] = [window number];
    [self send: POCKET_ORDER bytes: numbers length: sent * sizeof(uint32_t)];
}

- (void) windowCreated: (PocketWindow *) window {
    CFArrayAppendValue(_windows, window);
}

- (void) windowDestroyed: (PocketWindow *) window {
    CFIndex index = CFArrayGetFirstIndexOfValue(_windows, CFRangeMake(0, CFArrayGetCount(_windows)), window);
    if (index != kCFNotFound)
        CFArrayRemoveValueAtIndex(_windows, index);
    [self updateKeyboard];
}

- (void) windowRaised: (PocketWindow *) window {
    CFIndex count = CFArrayGetCount(_windows);
    CFIndex index = CFArrayGetFirstIndexOfValue(_windows, CFRangeMake(0, count), window);
    if (index == count - 1)
        return;
    if (index != kCFNotFound)
        CFArrayRemoveValueAtIndex(_windows, index);
    CFArrayAppendValue(_windows, window);
    [self sendOrder];
}

- (void) windowLowered: (PocketWindow *) window {
    CFIndex index = CFArrayGetFirstIndexOfValue(_windows, CFRangeMake(0, CFArrayGetCount(_windows)), window);
    if (index == 0)
        return;
    if (index != kCFNotFound)
        CFArrayRemoveValueAtIndex(_windows, index);
    CFArrayInsertValueAtIndex(_windows, 0, window);
    [self sendOrder];
}

- (NSArray *) orderedWindowNumbers {
    NSMutableArray *numbers = [NSMutableArray array];
    for (CFIndex i = CFArrayGetCount(_windows) - 1; i >= 0; i--) {
        PocketWindow *window = (PocketWindow *) CFArrayGetValueAtIndex(_windows, i);
        if ([window isVisible])
            [numbers addObject: [NSNumber numberWithInteger: [window windowNumber]]];
    }
    return numbers;
}

// Whether a responder takes typing: AppKit's text editors, and UIKit views
// that adopt UIKeyInput (a terminal, say). UIKit sits above AppKit, so its
// protocol is looked up by name; it exists once UIKit is loaded.
static BOOL respondsToTyping(NSResponder *responder) {
    if ([responder isKindOfClass: [NSText class]])
        return YES;
    Protocol *keyInput = objc_getProtocol("UIKeyInput");
    return keyInput != NULL && [responder conformsToProtocol: keyInput];
}

// What the text being edited asks of the keyboard: UITextInputTraits, which
// the UIKit view around an AppKit text editor holds (a UITextField around
// its field editor, a UITextView around its NSTextView), or the responder
// itself when it adopts UIKeyInput.
static uint32_t traitValue(id traits, const char *name) {
    SEL selector = sel_getUid(name);
    if (traits == nil || ![traits respondsToSelector: selector])
        return 0;
    return (uint32_t) ((NSInteger (*)(id, SEL)) objc_msgSend)(traits, selector);
}

static struct pocket_keyboard keyboardFor(NSResponder *responder) {
    struct pocket_keyboard keyboard = {1};
    id traits = nil;
    for (id view = responder; view != nil && traits == nil;
         view = [view isKindOfClass: [NSView class]] ? [(NSView *) view superview] : nil)
        if ([view respondsToSelector: @selector(keyboardType)])
            traits = view;
    keyboard.keyboard_type = traitValue(traits, "keyboardType");
    keyboard.return_key = traitValue(traits, "returnKeyType");
    keyboard.autocapitalization = traitValue(traits, "autocapitalizationType");
    keyboard.autocorrection = traitValue(traits, "autocorrectionType");
    SEL secure = sel_getUid("isSecureTextEntry");
    if ([traits respondsToSelector: secure] && ((BOOL (*)(id, SEL)) objc_msgSend)(traits, secure))
        keyboard.flags |= POCKET_KEYBOARD_SECURE;
    if ([responder isKindOfClass: [NSText class]] && ![(NSText *) responder isFieldEditor])
        keyboard.flags |= POCKET_KEYBOARD_MULTILINE;
    return keyboard;
}

- (void) updateKeyboard {
    NSWindow *window = [self keyWindow];
    NSResponder *responder = [window firstResponder];
    struct pocket_keyboard keyboard = {0};
    if ([window isVisible] && respondsToTyping(responder))
        keyboard = keyboardFor(responder);
    if (memcmp(&keyboard, &_keyboard, sizeof(keyboard)) == 0)
        return;
    _keyboard = keyboard;
    [self send: POCKET_KEYBOARD bytes: &keyboard length: sizeof(keyboard)];
}

// UIKit tells apps (UIKeyboardWillShowNotification and the rest).
NSString *const NSSoftKeyboardHeightDidChangeNotification = @"NSSoftKeyboardHeightDidChangeNotification";

- (void) keyboardFrameChanged: (struct pocket_keyboard_frame) frame {
    CGFloat height = frame.height / [self scale];
    if (height == _keyboardHeight)
        return;
    _keyboardHeight = height;
    [[NSNotificationCenter defaultCenter] postNotificationName: NSSoftKeyboardHeightDidChangeNotification
                                                        object: NSApp
                                                      userInfo: @{@"height": @(height)}];
}

#pragma mark - The screen

- (CGFloat) scale {
    return _screen.scale_milli / 1000.0;
}

- (NSRect) screenFrame {
    CGFloat scale = [self scale];
    return NSMakeRect(0, 0, _screen.width / scale, _screen.height / scale);
}

- (NSArray *) screens {
    if (_screens == nil) {
        CGFloat scale = [self scale];
        NSRect frame = [self screenFrame];
        PocketScreen *screen = [[[PocketScreen alloc] initWithFrame: frame visibleFrame: frame] autorelease];
        screen->_scale = scale;
        screen->_safeArea = NSEdgeInsetsMake(_screen.inset_top / scale, _screen.inset_left / scale,
                                             _screen.inset_bottom / scale, _screen.inset_right / scale);
        [screen setCgDirectDisplayID: 1];
        _screens = [[NSArray alloc] initWithObjects: screen, nil];
    }
    return [[_screens retain] autorelease];
}

- (CGFloat) backingScale {
    return [self scale];
}

- (NSRect) primaryRootFrame {
    return NSMakeRect(0, 0, _screen.width, _screen.height);
}

- (NSArray *) modesForScreen: (int) screenIndex {
    return [NSArray arrayWithObject: [self currentModeForScreen: screenIndex]];
}

- (NSDictionary *) currentModeForScreen: (int) screenIndex {
    return @{
        @"Width": @(_screen.width),
        @"Height": @(_screen.height),
        @"BitsPerPixel": @32,
        @"RefreshRate": @60,
    };
}

- (BOOL) setMode: (NSDictionary *) mode forScreen: (int) screenIndex {
    return NO;
}

// Windows have no frames on a phone.
- (CGRect) insetRect: (CGRect) frame forNativeWindowBorderWithStyle: (NSUInteger) styleMask {
    return frame;
}

- (CGRect) outsetRect: (CGRect) frame forNativeWindowBorderWithStyle: (NSUInteger) styleMask {
    return frame;
}

#pragma mark - Input devices

// Where the last finger was.
- (NSPoint) mouseLocation {
    return _lastTouch;
}

- (NSUInteger) currentModifierFlags {
    return _modifierFlags;
}

- (BOOL) warpMouse: (NSPoint) position {
    return NO;
}

- (void) grabMouse: (BOOL) doGrab {}
- (void) hideCursor {}
- (void) unhideCursor {}
- (id) cursorWithName: (NSString *) name { return nil; }
- (id) cursorWithImage: (NSImage *) image hotSpot: (NSPoint) hotSpot { return nil; }
- (void) setCursor: (id) cursor {}
- (void) beep {}

- (int) keyboardLayoutId {
    return 0;
}

- (void) keyboardLayoutName: (NSString **) name fullName: (NSString **) fullName {
    if (name)
        *name = @"us";
    if (fullName)
        *fullName = @"English (US)";
}

- (UCKeyboardLayout *) keyboardLayout: (uint32_t *) byteLength {
    if (byteLength)
        *byteLength = 0;
    return NULL;
}

- (NSPasteboard *) pasteboardWithName: (NSString *) name {
    PocketPasteboard *pasteboard = [_pasteboards objectForKey: name];
    if (pasteboard == nil) {
        pasteboard = [[[PocketPasteboard alloc] initWithName: name] autorelease];
        [_pasteboards setObject: pasteboard forKey: name];
    }
    return pasteboard;
}

- (NSDraggingManager *) draggingManager {
    return nil;
}

- (void) setWindow: (id) window forID: (XID) i {}
- (id) windowForID: (XID) i { return nil; }

@end
