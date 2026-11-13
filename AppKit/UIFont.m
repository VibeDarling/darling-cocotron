#import <AppKit/UIFont.h>
#import <AppKit/NSFontManager.h>

@implementation UIFontDescriptor

// GUESS: the UIKit attribute keys are taken to be the NSFontDescriptor ones; their values are not public.
- (NSString *) postscriptName {
    return [self objectForKey: NSFontNameAttribute];
}

@end

@implementation UIFont

// NSFont's own factories build plain NSFonts, so every font a UIFont method answers is wrapped in a UIFont.
static UIFont *wrap(NSFont *font) {
    if (font == nil) {
        return nil;
    }
    UIFont *result = [[UIFont alloc] init];
    result->_font = [font retain];
    return [result autorelease];
}

+ (UIFont *) fontWithName: (NSString *) fontName size: (CGFloat) fontSize {
    return wrap([NSFont fontWithName: fontName size: fontSize]);
}

- (void) dealloc {
    [_font release];
    [super dealloc];
}

// Every NSFont message that AppKit text code sends to a font attribute value (metrics, glyph and CTFont access)
// is answered by the wrapped font.
- (id) forwardingTargetForSelector: (SEL) selector {
    return _font;
}

// Archives hold the wrapped NSFont, so they unarchive wherever AppKit does (UIFont has no -initWithCoder:).
// A secure archiver asks the archived class; the NSFont that is written is secure.
+ (BOOL) supportsSecureCoding {
    return YES;
}

- (Class) classForCoder {
    return [NSFont class];
}

- (id) replacementObjectForCoder: (NSCoder *) coder {
    return _font;
}

- (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver *) archiver {
    return _font;
}

// Readers that check -respondsToSelector: before sending an NSFont message must see the forwarded ones.
- (BOOL) respondsToSelector: (SEL) selector {
    return [super respondsToSelector: selector] || [_font respondsToSelector: selector];
}

// For coders that do not substitute: the NSFont encoding in, the NSFont encoding out.
- (void) encodeWithCoder: (NSCoder *) coder {
    [_font encodeWithCoder: coder];
}

- (id) initWithCoder: (NSCoder *) coder {
    _font = [[NSFont alloc] initWithCoder: coder];
    return _font == nil ? nil : self;
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (NSString *) familyName {
    return [_font familyName];
}

- (NSString *) fontName {
    return [_font fontName];
}

- (CGFloat) pointSize {
    return [_font pointSize];
}

- (CGFloat) ascender {
    return [_font ascender];
}

- (CGFloat) descender {
    return [_font descender];
}

- (CGFloat) capHeight {
    return [_font capHeight];
}

- (CGFloat) xHeight {
    return [_font xHeight];
}

- (CGFloat) leading {
    return [_font leading];
}

// UIKit: a size of 0 takes the descriptor's own size.
+ (UIFont *) fontWithDescriptor: (NSFontDescriptor *) descriptor size: (CGFloat) pointSize {
    return wrap([NSFont fontWithDescriptor: descriptor size: pointSize == 0 ? [descriptor pointSize] : pointSize]);
}

+ (UIFont *) systemFontOfSize: (CGFloat) fontSize {
    return wrap([NSFont systemFontOfSize: fontSize]);
}

+ (UIFont *) systemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight {
    return wrap([NSFont systemFontOfSize: fontSize weight: weight]);
}

+ (UIFont *) boldSystemFontOfSize: (CGFloat) fontSize {
    return wrap([NSFont boldSystemFontOfSize: fontSize]);
}

+ (UIFont *) italicSystemFontOfSize: (CGFloat) fontSize {
    // -fontWithDescriptor:size: resolves by name and ignores a trait-only change, so the font manager adds the trait.
    NSFont *system = [NSFont systemFontOfSize: fontSize];
    return wrap([[NSFontManager sharedFontManager] convertFont: system toHaveTrait: NSItalicFontMask]);
}

+ (UIFont *) monospacedSystemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight {
    return wrap([NSFont monospacedSystemFontOfSize: fontSize weight: weight]);
}

+ (UIFont *) monospacedDigitSystemFontOfSize: (CGFloat) fontSize weight: (CGFloat) weight {
    return wrap([NSFont monospacedDigitSystemFontOfSize: fontSize weight: weight]);
}

+ (NSArray *) familyNames {
    return [[NSFontManager sharedFontManager] availableFontFamilies];
}

// -availableMembersOfFontFamily: answers one array per member, whose first element is the PostScript name.
+ (NSArray *) fontNamesForFamilyName: (NSString *) familyName {
    NSMutableArray *names = [NSMutableArray array];
    for (NSArray *member in [[NSFontManager sharedFontManager] availableMembersOfFontFamily: familyName]) {
        [names addObject: [member objectAtIndex: 0]];
    }
    return names;
}

// GUESS: UIKit does not document the formula; AppKit's default line height (ascent + descent + leading) is used.
- (CGFloat) lineHeight {
    return [_font defaultLineHeightForFont];
}

- (UIFont *) fontWithSize: (CGFloat) fontSize {
    return [UIFont fontWithName: [_font fontName] size: fontSize];
}

- (NSFont *) _wrappedFont {
    return _font;
}

- (UIFontDescriptor *) fontDescriptor {
    return [UIFontDescriptor fontDescriptorWithFontAttributes: [[_font fontDescriptor] fontAttributes]];
}

// NSFont has no -isEqual:; two UIFonts are equal when they have the same face name and size.
- (BOOL) isEqual: (id) other {
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass: [UIFont class]]) {
        return NO;
    }
    return [[self fontName] isEqualToString: [other fontName]] && [self pointSize] == [other pointSize];
}

- (NSUInteger) hash {
    return [[self fontName] hash] ^ (NSUInteger) ([self pointSize] * 64);
}

@end
