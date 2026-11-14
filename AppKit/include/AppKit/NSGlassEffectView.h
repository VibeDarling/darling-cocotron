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

#import <AppKit/AppKitExport.h>
#import <AppKit/NSView.h>

@class NSColor;

// GUESS: the raw values. Apple's documentation (macOS 26) lists the cases in the order regular, clear; it gives no numbers.
typedef NS_ENUM(NSInteger, NSGlassEffectViewStyle) {
    NSGlassEffectViewStyleRegular = 0,
    NSGlassEffectViewStyleClear = 1,
};

// A view that embeds its content view in a glass effect. The content view is hosted and sized to the
// glass; the glass effect itself is not drawn.
@interface NSGlassEffectView : NSView {
    NSView *_contentView;
    CGFloat _cornerRadius;
    NSColor *_tintColor;
    NSGlassEffectViewStyle _style;
    BOOL _effectIsInteractive;
}

@property (retain) NSView *contentView;
@property CGFloat cornerRadius;
@property (copy) NSColor *tintColor;
@property NSGlassEffectViewStyle style;
@property BOOL effectIsInteractive;

@end
