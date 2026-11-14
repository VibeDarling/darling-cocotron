#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

// CGContextSetFontSmoothingBackgroundColor is private (Calendar imports it). The prototype is the one Mozilla's
// open-source CGTextDrawing.h calls through dlsym. The call is accepted and changes nothing the public API can
// observe, so the test checks that it is exported, that it returns for a color and for NULL, and that the font
// state a public getter reports is the same before and after.
int main(void) {
    void (*setBackground)(CGContextRef, CGColorRef) =
        (void (*)(CGContextRef, CGColorRef)) dlsym(RTLD_DEFAULT, "CGContextSetFontSmoothingBackgroundColor");
    if (setBackground == NULL) { printf("FAIL: CGContextSetFontSmoothingBackgroundColor is exported\n"); return 1; }

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 4, 4, 8, 16, space, kCGImageAlphaPremultipliedLast);
    if (context == NULL) { printf("FAIL: a bitmap context\n"); return 1; }
    CGContextSetShouldSmoothFonts(context, true);
    CGContextSetAllowsFontSmoothing(context, false);
    uint32_t style = CGContextGetFontSmoothingStyle(context);

    CGColorRef red = CGColorCreateGenericRGB(1, 0, 0, 1);
    setBackground(context, red);
    setBackground(context, NULL);
    CGColorRelease(red);

    int failures = 0;
    if (!CGContextGetShouldSmoothFonts(context)) { printf("FAIL: should-smooth-fonts changed\n"); failures++; }
    if (CGContextGetAllowsFontSmoothing(context)) { printf("FAIL: allows-font-smoothing changed\n"); failures++; }
    if (CGContextGetFontSmoothingStyle(context) != style) { printf("FAIL: font smoothing style changed\n"); failures++; }
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    if (failures == 0) printf("PASS: CGContextSetFontSmoothingBackgroundColor\n");
    return failures ? 1 : 0;
}
