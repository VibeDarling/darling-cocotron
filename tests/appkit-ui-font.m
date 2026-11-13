// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// UIFont and UIFontDescriptor (UIKit documentation) answer from the font set and metrics of NSFont and
// NSFontDescriptor, which the AppKit-exported classes wrap; the expected values here come from NSFont.
int main(void) {
    @autoreleasepool {
        NSFont *reference = [NSFont systemFontOfSize:17];
        UIFont *font = [UIFont systemFontOfSize:17];
        expect(font != nil, @"the system font exists");
        expect([font pointSize] == 17, @"the point size is the requested one");
        expect([[font fontName] isEqualToString:[reference fontName]], @"the font name is the NSFont one");
        expect([[font familyName] isEqualToString:[reference familyName]], @"the family name is the NSFont one");
        expect([font ascender] == [reference ascender] && [font descender] == [reference descender], @"vertical metrics are the NSFont ones");
        expect([font capHeight] == [reference capHeight] && [font xHeight] == [reference xHeight], @"height metrics are the NSFont ones");
        expect([font leading] == [reference leading], @"leading is the NSFont one");
        expect([font lineHeight] > 0, @"a line has a height");

        UIFont *resized = [font fontWithSize:30];
        expect([resized pointSize] == 30 && [[resized fontName] isEqualToString:[font fontName]], @"fontWithSize: keeps the face");

        UIFont *bold = [UIFont boldSystemFontOfSize:17];
        expect(([[bold fontDescriptor] symbolicTraits] & UIFontDescriptorTraitBold) != 0, @"the bold system font has the bold trait");
        UIFont *named = [UIFont fontWithName:[font fontName] size:12];
        expect(named != nil && [named pointSize] == 12, @"a font is found by its own name");
        expect([[UIFont familyNames] count] > 0, @"the family list is not empty");

        UIFontDescriptor *descriptor = [UIFontDescriptor fontDescriptorWithName:[font fontName] size:21];
        expect([descriptor pointSize] == 21, @"the descriptor keeps its size");
        expect([[descriptor postscriptName] isEqualToString:[font fontName]], @"the descriptor keeps its name");
        expect([[descriptor fontDescriptorWithSize:9] pointSize] == 9, @"fontDescriptorWithSize: changes the size");
        expect([[descriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic] symbolicTraits] & UIFontDescriptorTraitItalic, @"the italic trait is applied");
        expect([[UIFont fontWithDescriptor:descriptor size:0] pointSize] == 21, @"size 0 takes the descriptor size");
        expect([[UIFont fontWithDescriptor:descriptor size:11] pointSize] == 11, @"an explicit size wins");
        expect([[UIFont italicSystemFontOfSize:17] pointSize] == 17, @"the italic system font has the requested size");
        // A UIFont stands in for an NSFont where AppKit text code takes a font attribute: it forwards the NSFont messages.
        UIFont *twin = [UIFont systemFontOfSize:17];
        expect([font isEqual:twin] && [font hash] == [twin hash], @"two fonts of one face and size are equal");
        expect(![font isEqual:resized], @"fonts of different sizes differ");
        expect(![font isEqual:nil] && ![font isEqual:reference], @"a UIFont is equal to UIFonts only");
        expect(![font isKindOfClass:[NSFont class]] && [[font fontDescriptor] isKindOfClass:[NSFontDescriptor class]], @"a UIFont wraps an NSFont and does not subclass it; its descriptor is an NSFontDescriptor");
        expect([[font copy] isEqual:font], @"a UIFont copies to an equal font");
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Hello"];
        [text addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 5)];
        expect([text attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] == font, @"the attribute keeps the UIFont");
        expect([[text attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] pointSize] == 17, @"the attribute answers its font's point size");
        NSMutableAttributedString *plain = [[NSMutableAttributedString alloc] initWithString:@"Hello"];
        [plain addAttribute:NSFontAttributeName value:reference range:NSMakeRange(0, 5)];
        NSSize uiSize = [text size], nsSize = [plain size];
        expect(uiSize.width > 0 && uiSize.width == nsSize.width && uiSize.height == nsSize.height, @"text measures the same with a UIFont as with its NSFont");
        expect([font respondsToSelector:@selector(fontName)] && [font respondsToSelector:@selector(defaultLineHeightForFont)], @"a UIFont responds to the NSFont messages it forwards");
        expect(![font respondsToSelector:NSSelectorFromString(@"noSuchFontMessage")], @"a UIFont does not respond to an unknown message");
        // An archive holds the wrapped NSFont: it unarchives anywhere, as an NSFont of the same face and size.
        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:font requiringSecureCoding:YES error:&error];
        expect(archive != nil, @"a UIFont archives");
        NSData *plainArchive = [NSKeyedArchiver archivedDataWithRootObject:font requiringSecureCoding:NO error:&error];
        expect(plainArchive != nil, @"a UIFont archives without secure coding");
        expect([[NSKeyedUnarchiver unarchiveObjectWithData:plainArchive] isKindOfClass:[NSFont class]], @"the plain archive of a UIFont unarchives to an NSFont");
        id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class] fromData:archive error:&error];
        expect(decoded != nil, @"the archive of a UIFont unarchives");
        expect([decoded isKindOfClass:[NSFont class]] && [[decoded fontName] isEqualToString:[font fontName]] && [decoded pointSize] == [font pointSize], @"the unarchived font has the face and size of the original");
        NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingFromData:archive error:&error];
        [reader setClass:[UIFont class] forClassName:@"NSFont"];
        id asUIFont = [reader decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        [reader finishDecoding];
        expect([asUIFont isKindOfClass:[UIFont class]] && [asUIFont isEqual:font], @"the NSFont archive of a UIFont decodes as an equal UIFont");
        NSLog(@"PASS: UIFont and UIFontDescriptor");
    }
    return 0;
}
