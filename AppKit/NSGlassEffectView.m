/*
 This file is part of Darling.

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

#import <AppKit/NSGlassEffectView.h>
#import <AppKit/NSColor.h>

// GUESS: a new view has a corner radius of 0 and no tint; the documentation states neither default.
@implementation NSGlassEffectView

@synthesize cornerRadius = _cornerRadius;
@synthesize style = _style;
@synthesize effectIsInteractive = _effectIsInteractive;

- (void) dealloc {
    [_contentView release];
    [_tintColor release];
    [super dealloc];
}

// A nib hands the glass its content view as its subview. GUESS: the archive keys of the documented properties
// are not public, so only the content view is taken, as the first subview.
- (instancetype) initWithCoder: (NSCoder *) coder {
    if ((self = [super initWithCoder: coder])) {
        NSArray *subviews = [self subviews];
        if ([subviews count] > 0) {
            _contentView = [[subviews objectAtIndex: 0] retain];
        }
    }
    return self;
}

- (NSView *) contentView {
    return _contentView;
}

- (void) setContentView: (NSView *) contentView {
    if (contentView == _contentView) {
        return;
    }
    if ([_contentView superview] == self) {
        [_contentView removeFromSuperview];
    }
    [_contentView release];
    _contentView = [contentView retain];
    if (_contentView != nil) {
        [_contentView setFrame: [self bounds]];
        [_contentView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
        [self addSubview: _contentView];
    }
}

- (NSColor *) tintColor {
    return _tintColor;
}

- (void) setTintColor: (NSColor *) tintColor {
    if (tintColor != _tintColor) {
        [_tintColor release];
        _tintColor = [tintColor copy];
    }
}

@end
