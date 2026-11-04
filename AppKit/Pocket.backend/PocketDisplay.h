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

// The display of a phone host (an Android app, or tools/pocket-host): one
// fullscreen screen whose size, scale and safe area the host gives, windows
// drawn into shared memory the host shows, and touches, keys and input method
// text from the host. The wire format is PocketProtocol.h.
//
// Selection: DARLING_POCKET_DISPLAY names the host's socket (a path inside
// the container). Without it, -init returns nil and NSDisplay goes on to the
// next backend.
//
// PocketDisplay subclasses X11Display, as WaylandDisplay does, for its parts
// that need no X server (system colours, fontconfig fonts, metrics). It never
// opens an X connection and overrides every method that would use one.

#import "X11Display.h"
#import "PocketProtocol.h"

@class PocketWindow;

@interface PocketDisplay : X11Display {
    int _socket;
    CFSocketRef _pocketSocket;
    CFRunLoopSourceRef _pocketSource;
    uint8_t _input[POCKET_MAX_MESSAGE * 4];
    size_t _inputLength;
    BOOL _nonblocking;

    struct pocket_screen _screen;
    BOOL _haveScreen;
    NSArray *_screens;

    // Bottom to top, not retained.
    CFMutableArrayRef _windows;
    NSPoint _lastTouch;
    struct pocket_keyboard _keyboard; // what the host was last asked for
    CGFloat _keyboardHeight;          // points, as the host last said
    NSMutableDictionary *_pasteboards;
}

// Pixels per point.
- (CGFloat) scale;
// The screen in points, AppKit's way up.
- (NSRect) screenFrame;

// Messages to the host. A send that fails ends the app: its host is gone.
- (void) send: (uint32_t) type bytes: (const void *) bytes length: (size_t) length;
- (void) send: (uint32_t) type bytes: (const void *) bytes length: (size_t) length fd: (int) fd;

- (void) windowCreated: (PocketWindow *) window;
- (void) windowDestroyed: (PocketWindow *) window;
- (void) windowRaised: (PocketWindow *) window;
- (void) windowLowered: (PocketWindow *) window;
// Asks the host to show the soft keyboard while text is being edited.
- (void) updateKeyboard;
// The host's keyboard came, went or resized: NSSoftKeyboardHeightDidChangeNotification.
- (void) keyboardFrameChanged: (struct pocket_keyboard_frame) frame;

@end
