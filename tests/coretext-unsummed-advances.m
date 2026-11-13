// CTFontGetUnsummedAdvancesForGlyphsAndStyle: GUESS (rung 6) semantics, one advance per glyph, never a running sum.
// Signature is that of the open WebKit CoreTextSPI.h.
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#include <math.h>
#include <stdio.h>

// Private name, not in the installed headers: prototype of the open WebKit CoreTextSPI.h.
typedef uint32_t CGFontRenderingStyle;
extern void CTFontGetUnsummedAdvancesForGlyphsAndStyle(CTFontRef, CTFontOrientation, CGFontRenderingStyle, const CGGlyph[], CGSize advances[], CFIndex count);

static int failures;
#define CHECK(cond, ...) do { if (cond) printf("PASS "); else { printf("FAIL "); ++failures; } printf(__VA_ARGS__); printf("\n"); } while (0)

int main(void) { @autoreleasepool {
    CTFontRef font = CTFontCreateWithName(CFSTR("DejaVu Sans"), 18, NULL);
    UniChar chars[3] = {'W', 'i', 'W'};
    CGGlyph glyphs[3];
    CHECK(CTFontGetGlyphsForCharacters(font, chars, glyphs, 3), "glyphs for W i W");

    // Independent expectation: the advance of each glyph asked for alone.
    CGSize single[3];
    for (int i = 0; i < 3; ++i) CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyphs[i], &single[i], 1);
    CHECK(single[0].width > 0 && single[1].width > 0 && single[0].width > single[1].width, "W (%.3f) is wider than i (%.3f)", single[0].width, single[1].width);

    CGSize all[3] = {{-1, -1}, {-1, -1}, {-1, -1}};
    CTFontGetUnsummedAdvancesForGlyphsAndStyle(font, kCTFontOrientationHorizontal, 0, glyphs, all, 3);
    for (int i = 0; i < 3; ++i)
        CHECK(fabs(all[i].width - single[i].width) < 0.001 && fabs(all[i].height - single[i].height) < 0.001, "entry %d is the advance of its own glyph (%.3f, want %.3f), not a running sum", i, all[i].width, single[i].width);

    // The style flags (antialiasing, subpixel positioning, quantization) are ignored by this stand-in.
    CGSize styled[3] = {{-1, -1}, {-1, -1}, {-1, -1}};
    CTFontGetUnsummedAdvancesForGlyphsAndStyle(font, kCTFontOrientationHorizontal, 1 | 2 | 4 | 8, glyphs, styled, 3);
    CHECK(styled[0].width == all[0].width && styled[1].width == all[1].width && styled[2].width == all[2].width, "a rendering style does not change the advances");

    CGSize one = {-1, -1};
    CTFontGetUnsummedAdvancesForGlyphsAndStyle(font, kCTFontOrientationHorizontal, 0, &glyphs[1], &one, 1);
    CHECK(fabs(one.width - single[1].width) < 0.001, "one glyph, one advance (WebKit's call shape)");

    CGSize untouched = {-1, -1};
    CTFontGetUnsummedAdvancesForGlyphsAndStyle(font, kCTFontOrientationHorizontal, 0, glyphs, &untouched, 0);
    CHECK(untouched.width == -1, "count 0 writes nothing");
    CFRelease(font);
    printf("RESULT failures=%d\n", failures);
    return failures ? 1 : 0;
} }
