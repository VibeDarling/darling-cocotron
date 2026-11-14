#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

// CGColorSpaceIsWideGamutRGB (macOS 10.12): "true if the color space is greater than 85% of the NTSC gamut".
// Expectations come from the published "percent of NTSC" figures of each standard (sRGB and BT.709 about 72%;
// Display P3, DCI-P3 and Adobe RGB 90-100%; BT.2020 and ROMM RGB well above), not from the code's own table.
static int failures;

static void expect(CFStringRef name, bool wide) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    char buffer[64];
    CFStringGetCString(name, buffer, sizeof buffer, kCFStringEncodingUTF8);
    if (space == NULL) { printf("FAIL: %s cannot be created\n", buffer); failures++; return; }
    if (CGColorSpaceIsWideGamutRGB(space) != wide) {
        printf("FAIL: %s should be %s\n", buffer, wide ? "wide gamut" : "not wide gamut"); failures++;
    }
    CGColorSpaceRelease(space);
}

int main(void) {
    if (dlsym(RTLD_DEFAULT, "CGColorSpaceIsWideGamutRGB") == NULL) { printf("FAIL: CGColorSpaceIsWideGamutRGB is not exported\n"); return 1; }
    expect(kCGColorSpaceSRGB, false);
    expect(kCGColorSpaceExtendedSRGB, false);
    expect(kCGColorSpaceLinearSRGB, false);
    expect(kCGColorSpaceExtendedLinearSRGB, false);
    expect(kCGColorSpaceITUR_709, false);
    expect(kCGColorSpaceGenericRGB, false);
    expect(kCGColorSpaceDisplayP3, true);
    expect(kCGColorSpaceExtendedDisplayP3, true);
    expect(kCGColorSpaceLinearDisplayP3, true);
    expect(kCGColorSpaceExtendedLinearDisplayP3, true);
    expect(kCGColorSpaceDCIP3, true);
    expect(kCGColorSpaceAdobeRGB1998, true);
    expect(kCGColorSpaceITUR_2020, true);
    expect(kCGColorSpaceITUR_2100_PQ, true);
    expect(kCGColorSpaceExtendedLinearITUR_2020, true);
    expect(kCGColorSpaceROMMRGB, true);

    CGColorSpaceRef device = CGColorSpaceCreateDeviceRGB();
    if (CGColorSpaceIsWideGamutRGB(device)) { printf("FAIL: device RGB is not wide gamut\n"); failures++; }
    CGColorSpaceRelease(device);
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    if (CGColorSpaceIsWideGamutRGB(gray)) { printf("FAIL: gray is not RGB\n"); failures++; }
    CGColorSpaceRelease(gray);
    CGColorSpaceRef cmyk = CGColorSpaceCreateDeviceCMYK();
    if (CGColorSpaceIsWideGamutRGB(cmyk)) { printf("FAIL: CMYK is not RGB\n"); failures++; }
    CGColorSpaceRelease(cmyk);
    if (CGColorSpaceIsWideGamutRGB(NULL)) { printf("FAIL: NULL is not wide gamut\n"); failures++; }

    if (failures == 0) printf("PASS: CGColorSpaceIsWideGamutRGB\n");
    return failures ? 1 : 0;
}
