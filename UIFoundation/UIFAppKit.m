/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

#import "UIFAppKit.h"
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#include <dlfcn.h>

Class UIFRequireAppKitClass(const char *name) {
    Class cls = objc_lookUpClass(name);

    if (cls == Nil)
        [NSException raise: NSInternalInconsistencyException
                    format: @"UIFoundation needs the AppKit class %s, but AppKit is not loaded in this process",
                            name];
    return cls;
}

void *UIFRequireAppKitSymbol(const char *name) {
    void *symbol = dlsym(RTLD_DEFAULT, name);

    if (symbol == NULL)
        [NSException raise: NSInternalInconsistencyException
                    format: @"UIFoundation needs the AppKit symbol %s, but AppKit is not loaded in this process",
                            name];
    return symbol;
}

// Layout needs AppKit at run time anyway (UIFAppKitClass above), and AppKit's helper is the one owner of the rule
// for what a font attribute is: it unwraps a UIFont (a wrapper that only forwards NSFont messages) to its NSFont,
// which layout needs because it caches IMPs of NSFont methods and hands the font to CoreText, and it supplies the
// default font.
NSFont *UIFFontAttributeInDictionary(NSDictionary *attributes) {
    return ((NSFont * (*)(NSDictionary *)) UIFAppKitSymbol(NSFontAttributeInDictionary))(attributes);
}

NSColor *UIFForegroundColorAttributeInDictionary(NSDictionary *attributes) {
    NSColor *color = [attributes objectForKey: NSForegroundColorAttributeName];

    if (color == nil)
        color = [UIFAppKitClass(NSColor) blackColor];

    return color;
}
