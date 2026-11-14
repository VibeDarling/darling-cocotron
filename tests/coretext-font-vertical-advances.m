#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

// Usage: coretext-font-vertical-advances FIXTURE_DIRECTORY (see generate-vertical-font.py).
// Covers CTFontGetAdvancesForGlyphs with kCTFontOrientationVertical against a font whose vhea/vmtx
// tables give each glyph a vertical advance that differs from its horizontal advance.
// GUESS (WebKit's use): the vertical advance is returned in .width with .height 0.
// NEEDS-REAL-MAC: that field choice, and the sign (FreeType reports it positive); only magnitudes are pinned.

#define CHECK(condition) do { if (!(condition)) { \
    fprintf(stderr, "failed line %d: %s\n", __LINE__, #condition); return 20; \
} } while (0)

static uint16_t be16(const uint8_t *bytes) { return (uint16_t)(bytes[0] << 8 | bytes[1]); }

// Vertical advance of a glyph in font units, read from the font's own vhea/vmtx tables.
static int tableVerticalAdvance(CGFontRef font, CGGlyph glyph)
{
    CFDataRef vhea = CGFontCopyTableForTag(font, 'vhea');
    CFDataRef vmtx = CGFontCopyTableForTag(font, 'vmtx');
    int result = -1;
    if (vhea != NULL && vmtx != NULL && CFDataGetLength(vhea) >= 36) {
        uint16_t metrics = be16(CFDataGetBytePtr(vhea) + 34);
        uint16_t index = glyph < metrics ? glyph : metrics - 1;
        if (CFDataGetLength(vmtx) >= (CFIndex)index * 4 + 4)
            result = be16(CFDataGetBytePtr(vmtx) + index * 4);
    }
    if (vhea != NULL) CFRelease(vhea);
    if (vmtx != NULL) CFRelease(vmtx);
    return result;
}

static int verifyFont(CGFontRef graphics, CGFloat size)
{
    CTFontRef font = CTFontCreateWithGraphicsFont(graphics, size, NULL, NULL);
    CHECK(font != NULL);
    const UniChar characters[] = {'A', 'B', 'C', 'B'};
    CGGlyph glyphs[4];
    CHECK(CTFontGetGlyphsForCharacters(font, characters, glyphs, 4));
    CGFloat unit = size / CGFontGetUnitsPerEm(graphics);

    CGSize horizontal[4], vertical[4], standard[4];
    double horizontalSum = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, glyphs, horizontal, 4);
    double standardSum = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs, standard, 4);
    double verticalSum = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationVertical, glyphs, vertical, 4);
    double verticalSumOnly = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationVertical, glyphs, NULL, 4);

    double expectedSum = 0;
    for (int i = 0; i < 4; ++i) {
        int units = tableVerticalAdvance(graphics, glyphs[i]);
        CHECK(units > 0);
        double expected = units * unit;
        expectedSum += expected;
        // The fixture has distinct metrics; the table, not the horizontal advance, is the oracle.
        CHECK(fabs(vertical[i].height) < 1e-6);
        CHECK(fabs(fabs(vertical[i].width) - expected) < 1e-6);
        CHECK(fabs(fabs(vertical[i].width) - horizontal[i].width) > 1);
        CHECK(fabs(standard[i].width - horizontal[i].width) < 1e-6);
        CHECK(fabs(standard[i].height - horizontal[i].height) < 1e-6);
    }
    CHECK(fabs(standardSum - horizontalSum) < 1e-6);
    CHECK(fabs(fabs(verticalSum) - expectedSum) < 1e-6);
    CHECK(fabs(verticalSumOnly - verticalSum) < 1e-6);
    CFRelease(font);
    return 0;
}

int main(int argc, const char **argv)
{
    if (argc != 2) return 2;
    @autoreleasepool {
        NSString *path = [[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:@"DarlingVerticalTest.ttf"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        CHECK(data != nil);
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
        CGFontRef graphics = CGFontCreateWithDataProvider(provider);
        CGDataProviderRelease(provider);
        CHECK(graphics != NULL);
        CHECK(tableVerticalAdvance(graphics, 2) == 600);
        // 20 and 40 points give whole-pixel advances for this font, so hinting cannot round them.
        int rc = verifyFont(graphics, 20);
        if (rc == 0) rc = verifyFont(graphics, 40);
        CGFontRelease(graphics);
        if (rc != 0) return rc;
    }
    puts("PASS");
    return 0;
}
