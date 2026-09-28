/* Copyright (c) 2026 Darling Developers

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. */

#import <AppKit/NSMenuToolbarItem.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>

@interface NSToolbarItem (NSMenuToolbarItemPrivate)
- (void)_didChange;
@end

@implementation NSMenuToolbarItem

- (instancetype)initWithItemIdentifier: (NSToolbarItemIdentifier) identifier {
    if ((self = [super initWithItemIdentifier: identifier])) {
        _menu = [[NSMenu alloc] initWithTitle: @""];
        _showsIndicator = YES;
    }
    return self;
}

- (id)copyWithZone: (NSZone *) zone {
    NSMenuToolbarItem *copy = [super copyWithZone: zone];
    copy->_menu = [_menu retain];
    return copy;
}

- (NSMenuItem *)menuFormRepresentation {
    NSMenuItem *item = [super menuFormRepresentation];
    [item setSubmenu: _menu];
    return item;
}

- (void)dealloc {
    [_menu release];
    [super dealloc];
}

- (void)setMenu: (NSMenu *) menu {
    if (menu == _menu)
        return;
    NSMenu *replacement = menu ? [menu retain] : [[NSMenu alloc] initWithTitle: @""];
    NSMenu *previous = _menu;
    _menu = replacement;
    [_menuFormRepresentation setSubmenu: _menu];
    [previous release];
    [self _didChange];
}

- (void)setShowsIndicator: (BOOL) showsIndicator {
    if (_showsIndicator == showsIndicator)
        return;
    _showsIndicator = showsIndicator;
    [self _didChange];
}

@synthesize menu = _menu;
@synthesize showsIndicator = _showsIndicator;

@end
