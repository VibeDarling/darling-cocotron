/*
 This file is part of Darling.

 Copyright (C) 2021 Lubos Dolezel

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

#import <AppKit/AKLayoutAnchor.h>
#import <AppKit/NSLayoutGuide.h>
#import <AppKit/NSView.h>
#import <Foundation/NSLayoutConstraint.h>

@implementation NSLayoutGuide

- (instancetype) init {
    self = [super init];
    if (self) {
        _frame = NSZeroRect;
        _owningView = nil;
        _identifier = nil;
    }
    return self;
}

- (void) dealloc {
    [_identifier release];
    [super dealloc];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    self = [super init];
    if (self) {
        if ([coder allowsKeyedCoding]) {
            _frame = [coder decodeRectForKey: @"NSFrame"];
            _identifier = [[coder decodeObjectForKey: @"NSUserInterfaceItemIdentifier"] copy];
        } else {
            _frame = NSZeroRect;
            _identifier = nil;
        }
        _owningView = nil;
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        [coder encodeRect: _frame forKey: @"NSFrame"];
        [coder encodeObject: _identifier forKey: @"NSUserInterfaceItemIdentifier"];
    }
}

- (NSView *) owningView {
    return _owningView;
}

- (void) setOwningView: (NSView *) view {
    _owningView = view;
}

- (id) nsli_superitem {
    return _owningView;
}

- (NSString *) identifier {
    return _identifier;
}

- (void) setIdentifier: (NSString *) identifier {
    if (_identifier != identifier) {
        [_identifier release];
        _identifier = [identifier copy];
    }
}

- (NSRect) frame {
    return _frame;
}

- (void) setFrame: (NSRect) frame {
    _frame = frame;
}

id AKLayoutAnchorForItem(id item, NSString *className, NSLayoutAttribute attribute) {
    Class cls = NSClassFromString(className);
    if (cls == Nil)
        cls = NSClassFromString(@"NSLayoutAnchor");
    if (cls == Nil || ![cls instancesRespondToSelector: @selector(initWithItem:attribute:)]) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"AppKit: layout anchors are unavailable: Foundation has no layout anchor class "
                  @"implementing -initWithItem:attribute: (looked for %@ and NSLayoutAnchor); "
                  @"anchor properties return nil",
                  className);
        });
        return nil;
    }
    return [[[cls alloc] initWithItem: item attribute: attribute] autorelease];
}

- (NSLayoutXAxisAnchor *) leadingAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutXAxisAnchor", NSLayoutAttributeLeading);
}

- (NSLayoutXAxisAnchor *) trailingAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutXAxisAnchor", NSLayoutAttributeTrailing);
}

- (NSLayoutXAxisAnchor *) leftAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutXAxisAnchor", NSLayoutAttributeLeft);
}

- (NSLayoutXAxisAnchor *) rightAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutXAxisAnchor", NSLayoutAttributeRight);
}

- (NSLayoutYAxisAnchor *) topAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutYAxisAnchor", NSLayoutAttributeTop);
}

- (NSLayoutYAxisAnchor *) bottomAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutYAxisAnchor", NSLayoutAttributeBottom);
}

- (NSLayoutDimension *) widthAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutDimension", NSLayoutAttributeWidth);
}

- (NSLayoutDimension *) heightAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutDimension", NSLayoutAttributeHeight);
}

- (NSLayoutXAxisAnchor *) centerXAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutXAxisAnchor", NSLayoutAttributeCenterX);
}

- (NSLayoutYAxisAnchor *) centerYAnchor {
    return AKLayoutAnchorForItem(self, @"NSLayoutYAxisAnchor", NSLayoutAttributeCenterY);
}

@end
