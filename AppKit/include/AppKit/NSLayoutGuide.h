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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>
#import <AppKit/NSUserInterfaceItemIdentification.h>

@class NSView, NSLayoutXAxisAnchor, NSLayoutYAxisAnchor, NSLayoutDimension;

@interface NSLayoutGuide : NSObject <NSCoding, NSUserInterfaceItemIdentification>
// The instance variables are AppKit's own. UIKit's classes are built on this one, and iOS
// code that subclasses them must not see them: names such as _frame or _layer would clash
// with its own. The runtime places a subclass's ivars after them either way.
#if !TARGET_OS_IPHONE
{
    NSRect _frame;
    NSView *_owningView;
    NSString *_identifier;
}
#endif

- (instancetype) init;
- (instancetype) initWithCoder: (NSCoder *) coder;
- (void) encodeWithCoder: (NSCoder *) coder;

@property (assign) NSView *owningView;
@property (copy) NSString *identifier;
@property (readonly) NSRect frame;

@property (readonly, strong) NSLayoutXAxisAnchor *leadingAnchor;
@property (readonly, strong) NSLayoutXAxisAnchor *trailingAnchor;
@property (readonly, strong) NSLayoutXAxisAnchor *leftAnchor;
@property (readonly, strong) NSLayoutXAxisAnchor *rightAnchor;
@property (readonly, strong) NSLayoutYAxisAnchor *topAnchor;
@property (readonly, strong) NSLayoutYAxisAnchor *bottomAnchor;
@property (readonly, strong) NSLayoutDimension *widthAnchor;
@property (readonly, strong) NSLayoutDimension *heightAnchor;
@property (readonly, strong) NSLayoutXAxisAnchor *centerXAnchor;
@property (readonly, strong) NSLayoutYAxisAnchor *centerYAnchor;

@end
