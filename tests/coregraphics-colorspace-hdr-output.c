#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

// CGColorSpaceIsHDR and CGColorSpaceSupportsOutput (Freeform, ColorSync Utility) are public but the
// documentation does not give their answers. The expected values are what a real Mac returned (macOS 26.1,
// probe 12 section 3, darling_probe12.txt lines 26-45), for every space Cocotron can create. Not covered:
// kCGColorSpaceDisplayP3_PQ and kCGColorSpaceITUR_2100_HLG, which Cocotron cannot create, and NULL.
typedef bool (*Query)(CGColorSpaceRef);

static int check(const char *label, Query isHDR, Query supports, CGColorSpaceRef space, int hdr, int output) {
    if (space == NULL) { printf("FAIL: %s could not be created\n", label); return 1; }
    int gotHDR = isHDR(space) ? 1 : 0, gotOutput = supports(space) ? 1 : 0;
    if (gotHDR != hdr || gotOutput != output) {
        printf("FAIL: %s: IsHDR %d (expected %d), SupportsOutput %d (expected %d)\n", label, gotHDR, hdr, gotOutput, output);
        return 1;
    }
    return 0;
}

int main(void) {
    Query isHDR = (Query) dlsym(RTLD_DEFAULT, "CGColorSpaceIsHDR");
    Query supports = (Query) dlsym(RTLD_DEFAULT, "CGColorSpaceSupportsOutput");
    if (isHDR == NULL) { printf("FAIL: CGColorSpaceIsHDR is exported\n"); return 1; }
    if (supports == NULL) { printf("FAIL: CGColorSpaceSupportsOutput is exported\n"); return 1; }
    int failures = 0;
    static const struct { const CFStringRef *name; const char *label; int hdr; } named[] = {
        {&kCGColorSpaceSRGB, "sRGB", 0}, {&kCGColorSpaceLinearSRGB, "linear sRGB", 0},
        {&kCGColorSpaceExtendedSRGB, "extended sRGB", 0}, {&kCGColorSpaceExtendedLinearSRGB, "extended linear sRGB", 0},
        {&kCGColorSpaceDisplayP3, "Display P3", 0}, {&kCGColorSpaceITUR_2020, "ITU-R 2020", 0},
        {&kCGColorSpaceITUR_2100_PQ, "ITU-R 2100 PQ", 1}, {&kCGColorSpaceGenericGrayGamma2_2, "generic gray 2.2", 0},
        {&kCGColorSpaceGenericRGB, "generic RGB", 0}, {&kCGColorSpaceGenericCMYK, "generic CMYK", 0},
        {&kCGColorSpaceGenericLab, "generic Lab", 0}, {&kCGColorSpaceGenericXYZ, "generic XYZ", 0},
        {&kCGColorSpaceExtendedGray, "extended gray", 0},
    };
    for (size_t i = 0; i < sizeof named / sizeof named[0]; i++) {
        CGColorSpaceRef space = CGColorSpaceCreateWithName(*named[i].name);
        failures += check(named[i].label, isHDR, supports, space, named[i].hdr, 1);
        if (space) CGColorSpaceRelease(space);
    }
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB(), gray = CGColorSpaceCreateDeviceGray(), cmyk = CGColorSpaceCreateDeviceCMYK();
    failures += check("device RGB", isHDR, supports, rgb, 0, 1);
    failures += check("device gray", isHDR, supports, gray, 0, 1);
    failures += check("device CMYK", isHDR, supports, cmyk, 0, 1);
    CGColorSpaceRef pattern = CGColorSpaceCreatePattern(NULL);
    failures += check("pattern", isHDR, supports, pattern, 0, 0);
    if (pattern) CGColorSpaceRelease(pattern);
    CGColorSpaceRelease(rgb); CGColorSpaceRelease(gray); CGColorSpaceRelease(cmyk);
    // Found through dlsym like the functions, so one binary runs against an image that lacks it. Observed value: the name.
    const CFStringRef *hlg = (const CFStringRef *) dlsym(RTLD_DEFAULT, "kCGColorSpaceITUR_2100_HLG");
    if (hlg == NULL || *hlg == NULL || CFEqual(*hlg, CFSTR("kCGColorSpaceITUR_2100_HLG")) == 0) {
        printf("FAIL: kCGColorSpaceITUR_2100_HLG is exported with the observed value\n"); failures++;
    }
    if (failures == 0) printf("PASS: CGColorSpaceIsHDR, CGColorSpaceSupportsOutput, kCGColorSpaceITUR_2100_HLG\n");
    return failures ? 1 : 0;
}
