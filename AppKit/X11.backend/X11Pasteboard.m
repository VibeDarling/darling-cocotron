/*
This file is part of Darling.

Copyright (C) 2019 Lubos Dolezel

Darling is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Darling is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "X11Pasteboard.h"

// A value too large for one request is transferred incrementally: the property
// is set to the type INCR holding the total length, and the receiver deletes it
// to ask for the next chunk. 64 KiB is comfortably inside the request size the
// protocol guarantees without BIG-REQUESTS.
static const NSUInteger X11IncrChunkSize = 64 * 1024;
static const NSUInteger X11IncrThreshold = 4 * X11IncrChunkSize;

// One transfer in progress. Keyed by requestor window, because a requestor that
// has deleted the property cannot say which transfer it wants to continue.
@interface X11IncrTransfer : NSObject {
@public
    Atom _property;
    Atom _type;
    NSData *_data;
    NSUInteger _offset;
}

- (id) initWithProperty: (Atom) property
                  type: (Atom) type
                  data: (NSData *) data;

@end

@implementation X11IncrTransfer

- (id) initWithProperty: (Atom) property
                  type: (Atom) type
                  data: (NSData *) data
{
    if ((self = [super init])) {
        _property = property;
        _type = type;
        _data = [data retain];
    }
    return self;
}

- (void) dealloc {
    [_data release];
    [super dealloc];
}

@end

@implementation X11Pasteboard

static NSMutableDictionary<NSPasteboardName, X11Pasteboard *> *nameToPboard;

+ (X11Pasteboard *) pasteboardWithName: (NSPasteboardName) name {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      nameToPboard = [NSMutableDictionary new];
    });

    if ([name isEqual: NSGeneralPboard]) {
        name = @"CLIPBOARD";
    }

    if (nameToPboard[name] == nil) {
        nameToPboard[name] = [[X11Pasteboard alloc] initWithName: name];
    }

    return nameToPboard[name];
}

- (instancetype) initWithName: (NSPasteboardName) name {
    self = [super init];
    _name = [name retain];

    X11Display *x11Display = (X11Display *) [NSDisplay currentDisplay];

    _display = [x11Display display];
    _selectionName = XInternAtom(_display, [name UTF8String], False);
    _receivingProperty = XInternAtom(_display, "RECEIVING_PROPERTY", False);
    _incrAtom = XInternAtom(_display, "INCR", False);

    int screen = DefaultScreen(_display);
    _window = XCreateSimpleWindow(_display, RootWindow(_display, screen), -10,
                                  -10, 1, 1, 0, 0, 0);
    XSelectInput(_display, _window,
                 SelectionClear | SelectionRequest | SelectionNotify |
                         PropertyNotify);

    [x11Display setWindow: self forID: _window];

    return self;
}

- (void) ensureSelectionOwner {
    if (_typeToData != nil) {
        // Already an owner.
        return;
    }

    XSetSelectionOwner(_display, _selectionName, _window,
                       CurrentTime); // FIXME: don't use CurrentTime
    XFlush(_display);

    _typeToData = [NSMutableDictionary new];
    _typeToOwner = [NSMutableDictionary new];

    _changeCount++;
}

- (NSInteger) clearContents {
    [self ensureSelectionOwner];

    for (id owner in [_typeToOwner allValues]) {
        [owner pasteboardChangedOwner: self];
    }
    [_typeToOwner removeAllObjects];
    [_typeToData removeAllObjects];

    return _changeCount;
}

- (void) giveUpSelectionOwner {
    _changeCount++;

    [self clearContents];

    [_typeToOwner release];
    _typeToOwner = nil;

    [_typeToData release];
    _typeToData = nil;
}

- (NSString *) name {
    return _name;
}

- (void) dealloc {
    [(X11Display *) [NSDisplay currentDisplay] setWindow: nil forID: _window];
    XDestroyWindow(_display, _window);

    [self giveUpSelectionOwner];
    [_name release];
    [super dealloc];
}

- (NSInteger) changeCount {
    return _changeCount;
}

- (void) selectionClear: (XSelectionClearEvent *) event {
    [self giveUpSelectionOwner];
}

+ (NSArray<NSString *> *) targetsForType: (NSPasteboardType) type {
    if ([type isEqual: NSStringPboardType]) {
        return @[
            @"UTF8_STRING", @"STRING", @"TEXT", @"text/plain",
            @"text/plain;charset=utf-8"
        ];
    }
    // TODO...
    return @[ type ];
}

+ (NSPasteboardType) typeForTarget: (NSString *) target {
    if ([target isEqual: @"STRING"] || [target isEqual: @"TEXT"] ||
        [target isEqual: @"text/plain"] ||
        [target isEqual: @"text/plain;charset=utf-8"] ||
        [target isEqual: @"UTF8_STRING"]) {
        return NSStringPboardType;
    }
    // TODO...
    return target;
}

- (NSData *) readDataFromReceivingProperty {
    Atom type;
    unsigned char *propValue = NULL;
    int format;
    unsigned long num_items, remaining;

    XGetWindowProperty(_display, _window, _receivingProperty, 0, ~0L, True,
                       AnyPropertyType, &type, &format, &num_items, &remaining,
                       &propValue);

    if (type == None) {
        return nil;
    }

    if (type == _incrAtom) {
        NSLog(@"Unimplemented: INCR support");
        return nil;
    }

    if (format != 8) {
        // ???
        XFree(propValue);
        return nil;
    }

    NSData *data = [NSData dataWithBytes: propValue length: num_items];
    XFree(propValue);

    return data;
}

- (NSData *) dataForType: (NSPasteboardType) type {

    if (_typeToOwner != nil) {
        // We're the owner; just fetch the data directly.
        id<NSPasteboardTypeOwner> owner = _typeToOwner[type];
        [owner pasteboard: self provideDataForType: type];
        return _typeToData[type];
    }

    NSString *target = [X11Pasteboard targetsForType: type][0];
    Atom targetAtom = XInternAtom(_display, [target UTF8String], False);
    XConvertSelection(_display, _selectionName, targetAtom, _receivingProperty,
                      _window, CurrentTime); // FIXME: don't use CurrentTime

    _selectionNotifyResult = WAITING;
    while (_selectionNotifyResult == WAITING) {
        [[NSDisplay currentDisplay]
                nextEventMatchingMask: NSAnyEventMask
                            untilDate: [NSDate distantFuture]
                               inMode: NSDefaultRunLoopMode
                              dequeue: NO];
    }

    return [self readDataFromReceivingProperty];
}

- (NSString *) stringForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];

    NSStringEncoding encoding = NSUnicodeStringEncoding;
    if ([type isEqual: NSStringPboardType]) {
        encoding = NSUTF8StringEncoding;
    }
    return [[[NSString alloc] initWithData: data
                                  encoding: encoding] autorelease];
}

- (NSInteger) addTypes: (NSArray<NSPasteboardType> *) types
                 owner: (id<NSPasteboardTypeOwner>) owner
{
    [self ensureSelectionOwner];
    for (NSPasteboardType type in types) {
        [_typeToData removeObjectForKey: type];
        _typeToOwner[type] = owner;
    }
    return _changeCount;
}

- (NSInteger) declareTypes: (NSArray<NSPasteboardType> *) types
                     owner: (id<NSPasteboardTypeOwner>) owner
{
    [self clearContents];
    return [self addTypes: types owner: owner];
}

- (BOOL) setData: (NSData *) data forType: (NSPasteboardType) type {
    [self ensureSelectionOwner];
    // Make sure to retain data before releasing the owner,
    // because it might be the owner that is providing us
    // with this data.
    _typeToData[type] = data;
    // NOT SENT: [_typeToOwner[type] pasteboardChangedOwner: self];
    [_typeToOwner removeObjectForKey: type];
    return YES;
}

- (BOOL) setString: (NSString *) string forType: (NSPasteboardType) type {
    NSStringEncoding encoding = NSUnicodeStringEncoding;
    if ([type isEqual: NSStringPboardType]) {
        encoding = NSUTF8StringEncoding;
    }
    NSData *data = [string dataUsingEncoding: encoding];
    return [self setData: data forType: type];
}

- (NSArray<NSPasteboardType> *) types {
    return [[_typeToData allKeys]
            arrayByAddingObjectsFromArray: [_typeToOwner allKeys]];
}

- (void) selectionNotify: (XSelectionEvent *) event {
    if (event->property == None) {
        _selectionNotifyResult = NONE;
    } else {
        _selectionNotifyResult = SUCCESS;
    }
}

- (void) selectionRequest: (XSelectionRequestEvent *) event {
    void (^reply)(BOOL success) = ^(BOOL success) {
      XEvent replyEvent;
      XSelectionEvent *re = &replyEvent.xselection;
      re->type = SelectionNotify;
      re->requestor = event->requestor;
      re->selection = event->selection;
      re->target = event->target;
      re->property = success ? event->property : None;
      re->time = event->time;
      XSendEvent(_display, event->requestor, True, NoEventMask, &replyEvent);
      XFlush(_display);
    };

    if (event->target == None) {
        reply(NO);
        return;
    }

    char *rawTarget = XGetAtomName(_display, event->target);
    NSString *target = [NSString stringWithUTF8String: rawTarget];
    XFree(rawTarget);

    if ([target isEqual: @"TARGETS"]) {
        NSArray<NSPasteboardType> *types = [self types];
        size_t count = 1;
        for (NSPasteboardType type in types) {
            NSArray<NSString *> *ts = [X11Pasteboard targetsForType: type];
            count += [ts count];
        }
        Atom targets[count];
        size_t i = 0;
        for (NSPasteboardType type in types) {
            NSArray<NSString *> *ts = [X11Pasteboard targetsForType: type];
            for (NSString *t in ts) {
                targets[i++] = XInternAtom(_display, [t UTF8String], False);
            }
        }
        targets[i++] = event->target; // TARGETS itself

        XChangeProperty(_display, event->requestor, event->property,
                        event->target, 32, PropModeReplace,
                        (unsigned char *) targets, count);
        reply(YES);
        return;
    }

    NSPasteboardType type = [X11Pasteboard typeForTarget: target];

    id<NSPasteboardTypeOwner> owner = _typeToOwner[type];
    [owner pasteboard: self provideDataForType: type];

    NSData *data = _typeToData[type];
    if (data == nil) {
        reply(NO);
        return;
    }

    if ([data length] > X11IncrThreshold) {
        [self startTransferOfData: data
                            type: event->target
                     toRequestor: event->requestor
                      onProperty: event->property];
        reply(YES);
        return;
    }

    XChangeProperty(_display, event->requestor, event->property, event->target,
                    8, PropModeReplace, [data bytes], [data length]);

    reply(YES);
}

// The property goes up as the type INCR carrying the total length, and only the
// chunks replace it with the value's own type. Writing a chunk before the
// receiver has read that header would hide the INCR marker, so the first chunk
// waits for the receiver to delete the property.
- (void) startTransferOfData: (NSData *) data
                        type: (Atom) type
                 toRequestor: (Window) requestor
                  onProperty: (Atom) property
{
    // The receiver's window is not ours, so this is the only way to learn when it
    // is ready for the next chunk.
    XSelectInput(_display, requestor, PropertyChangeMask);
    unsigned long length = (unsigned long) [data length];
    XChangeProperty(_display, requestor, property, _incrAtom, 32, PropModeReplace,
                    (unsigned char *) &length, 1);
    if (_incrTransfers == nil)
        _incrTransfers = [[NSMutableDictionary alloc] init];
    _incrTransfers[[NSNumber numberWithUnsignedLong: requestor]] =
            [[X11IncrTransfer alloc] initWithProperty: property type: type data: data];
    XFlush(_display);
}

- (void) propertyNotify: (XPropertyEvent *) event {
    // ICCCM paces an incremental transfer with property deletions: the receiver
    // reads a chunk and deletes the property to ask for the next one, and a
    // receiver that aborts deletes it without asking.
    NSNumber *requestor = [NSNumber numberWithUnsignedLong: event->window];
    X11IncrTransfer *transfer = _incrTransfers[requestor];
    if (transfer == nil || event->state != PropertyDelete ||
        transfer->_property != event->atom)
        return;

    NSUInteger left = [transfer->_data length] - transfer->_offset;
    NSUInteger chunk = left > X11IncrChunkSize ? X11IncrChunkSize : left;
    if (chunk == 0) {
        // Nothing left to send: the transfer is over, and deleting the property
        // is what tells the receiver so.
        [_incrTransfers removeObjectForKey: requestor];
        XDeleteProperty(_display, event->window, event->atom);
        XFlush(_display);
        [transfer release];
        return;
    }
    XChangeProperty(_display, event->window, event->atom, transfer->_type, 8,
                    PropModeReplace, [transfer->_data bytes] + transfer->_offset, chunk);
    transfer->_offset += chunk;
    XFlush(_display);
}

- (Window) windowHandle {
    return _window;
}

- (Atom) selectionAtom {
    return _selectionName;
}

- (id) delegate {
    // To sook somewhat like an X11Window to X11Display.
    return nil;
}

@end
