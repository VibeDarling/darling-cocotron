#import <AppKit/AppKitExport.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontDescriptor.h>
#import <CoreGraphics/CGBase.h>
#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

// The UIKit font classes that AppKit exports for UIKit-for-Mac clients. UIFont wraps an NSFont and answers from
// the same font set and metrics: the methods below are its own and every other message (the NSFont API that
// AppKit text code sends to an NSFontAttributeName value) is forwarded to the wrapped font. It is deliberately
// not an NSFont subclass: NSFont is moving out of AppKit. UIFontDescriptor is an NSFontDescriptor.

typedef uint32_t UIFontDescriptorSymbolicTraits;
enum {
    UIFontDescriptorTraitItalic = 1u << 0,
    UIFontDescriptorTraitBold = 1u << 1,
    UIFontDescriptorTraitExpanded = 1u << 5,
    UIFontDescriptorTraitCondensed = 1u << 6,
    UIFontDescriptorTraitMonoSpace = 1u << 10,
    UIFontDescriptorTraitVertical = 1u << 11,
    UIFontDescriptorTraitUIOptimized = 1u << 12,
    UIFontDescriptorTraitTightLeading = 1u << 15,
    UIFontDescriptorTraitLooseLeading = 1u << 16,
};

@interface UIFontDescriptor : NSFontDescriptor

@property(readonly, nullable) NSString *postscriptName;

@end

@interface UIFont : NSObject <NSCopying, NSSecureCoding> {
    NSFont *_font;
}

+ (nullable UIFont *) fontWithName: (NSString *) fontName size: (CGFloat) fontSize;
+ (UIFont *) fontWithDescriptor: (NSFontDescriptor *) descriptor size: (CGFloat) pointSize;
+ (UIFont *) systemFontOfSize: (CGFloat) fontSize;
+ (UIFont *) systemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight;
+ (UIFont *) boldSystemFontOfSize: (CGFloat) fontSize;
+ (UIFont *) italicSystemFontOfSize: (CGFloat) fontSize;
+ (UIFont *) monospacedSystemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight;
+ (UIFont *) monospacedDigitSystemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight;
+ (NSArray<NSString *> *) familyNames;
+ (NSArray<NSString *> *) fontNamesForFamilyName: (NSString *) familyName;

@property(readonly) NSString *familyName;
@property(readonly) NSString *fontName;
@property(readonly) CGFloat pointSize;
@property(readonly) CGFloat ascender;
@property(readonly) CGFloat descender;
@property(readonly) CGFloat capHeight;
@property(readonly) CGFloat xHeight;
@property(readonly) CGFloat leading;
@property(readonly) CGFloat lineHeight;

- (UIFont *) fontWithSize: (CGFloat) fontSize;
- (UIFontDescriptor *) fontDescriptor;

// The NSFont this one wraps: AppKit text layout needs a real NSFont (a CTFontRef).
- (NSFont *) _wrappedFont;

@end

NS_ASSUME_NONNULL_END
