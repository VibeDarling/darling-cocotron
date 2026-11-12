/* Copyright (c) 2009 Andy Balholm

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

#import "NSCellUndoManager.h"

#import <Foundation/Foundation.h>

// Target of the throwaway registration that clears the next manager's redo stack.
@interface AKCellUndoSentinel : NSObject
- (void) noop: (id) unused;
@end

@implementation AKCellUndoSentinel
- (void) noop: (id) unused {
}
@end

static AKCellUndoSentinel *sentinel;

@implementation NSCellUndoManager

+ (void) initialize {
    if (self == [NSCellUndoManager class])
        sentinel = [AKCellUndoSentinel new];
}

- (instancetype) init {
    self = [super init];
    if (self != nil)
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(_cellUndoGroupWillClose:)
                       name: NSUndoManagerWillCloseUndoGroupNotification
                     object: self];
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_nextUndoManager release];
    [super dealloc];
}

// A new undo registration discards the redo stack of the manager it goes to. Registrations here
// go to this manager, so make the next one forget its redo stack the documented way: register
// outside undo and redo, then take that action back. Nothing is left on its undo stack.
- (void) _dropRedoOfNext {
    NSUndoManager *next = _nextUndoManager;

    if (next == nil || [next isUndoing] || [next isRedoing] ||
        ![next isUndoRegistrationEnabled] || ![next canRedo])
        return;

    BOOL openedGroup = [next groupingLevel] == 0;
    if (openedGroup)
        [next beginUndoGrouping];
    [next registerUndoWithTarget: sentinel selector: @selector(noop:) object: nil];
    [next removeAllActionsWithTarget: sentinel];
    if (openedGroup)
        [next endUndoGrouping];
}

- (void) _cellUndoGroupWillClose: (NSNotification *) note {
    [self _dropRedoOfNext];
}

- (BOOL) canUndo {
    return [super canUndo] || [_nextUndoManager canUndo];
}

- (void) undo {
    if ([super canUndo]) {
        [super undo];
    } else {
        [_nextUndoManager undo];
    }
}

- (BOOL) canRedo {
    return [_nextUndoManager canRedo] || [super canRedo];
}

- (void) redo {
    if ([_nextUndoManager canRedo]) {
        [_nextUndoManager redo];
    } else {
        [super redo];
    }
}

- (void) setNextUndoManager: (NSUndoManager *) manager {
    [manager retain];
    [_nextUndoManager release];
    _nextUndoManager = manager;
}

- (void) forwardInvocation: (NSInvocation *) invocation {
    [super forwardInvocation: invocation];
    [self _dropRedoOfNext];
}

- (void) registerUndoWithTarget: (id) target
                       selector: (SEL) selector
                         object: (id) object
{
    [super registerUndoWithTarget: target selector: selector object: object];
    [self _dropRedoOfNext];
}

@end
