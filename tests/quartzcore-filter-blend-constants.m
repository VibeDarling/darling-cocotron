#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// Books and App Store import these private QuartzCore string constants. The expected values are what a real Mac
// printed for each (macOS 26.1, probe 11 section 1, darling_probe11.txt lines 3-39); the test finds each constant
// through dlsym so one binary runs against an image that lacks it, and also checks that it works as a CAFilter type.
@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@property(readonly, copy) NSString *type;
@end

int main(void) {
    static const struct { const char *name; const char *value; } expected[] = {
        {"kCAFilterPlusD", "plusD"},
        {"kCAFilterPlusL", "plusL"},
        {"kCAFilterColorBlendMode", "colorBlendMode"},
        {"kCAFilterColorBurnBlendMode", "colorBurnBlendMode"},
        {"kCAFilterColorDodgeBlendMode", "colorDodgeBlendMode"},
        {"kCAFilterDarkenBlendMode", "darkenBlendMode"},
        {"kCAFilterDarkenSourceOver", "darkenSourceOver"},
        {"kCAFilterDestOut", "destOut"},
        {"kCAFilterDifferenceBlendMode", "differenceBlendMode"},
        {"kCAFilterDivideBlendMode", "divideBlendMode"},
        {"kCAFilterExclusionBlendMode", "exclusionBlendMode"},
        {"kCAFilterHardLightBlendMode", "hardLightBlendMode"},
        {"kCAFilterHueBlendMode", "hueBlendMode"},
        {"kCAFilterLightenBlendMode", "lightenBlendMode"},
        {"kCAFilterLightenSourceOver", "lightenSourceOver"},
        {"kCAFilterLinearBurnBlendMode", "linearBurnBlendMode"},
        {"kCAFilterLinearDodgeBlendMode", "linearDodgeBlendMode"},
        {"kCAFilterLinearLightBlendMode", "linearLightBlendMode"},
        {"kCAFilterLuminosityBlendMode", "luminosityBlendMode"},
        {"kCAFilterMaximum", "maximum"},
        {"kCAFilterMinimum", "minimum"},
        {"kCAFilterMultiply", "multiply"},
        {"kCAFilterNormalBlendMode", "normalBlendMode"},
        {"kCAFilterOverlayBlendMode", "overlayBlendMode"},
        {"kCAFilterPinLightBlendMode", "pinLightBlendMode"},
        {"kCAFilterSaturationBlendMode", "saturationBlendMode"},
        {"kCAFilterScreenBlendMode", "screenBlendMode"},
        {"kCAFilterSoftLightBlendMode", "softLightBlendMode"},
        {"kCAFilterSubtractBlendMode", "subtractBlendMode"},
        {"kCAFilterSubtractD", "subtractD"},
        {"kCAFilterSubtractS", "subtractS"},
        {"kCALayerContentsSwizzleAAAA", "AAAA"},
        {"kCALayerContentsSwizzleRGBA", "RGBA"},
        {"kCAContentsFormatA8", "A8"},
    };
    int count = (int)(sizeof expected / sizeof expected[0]);
    int failures = 0;
    @autoreleasepool {
        for (int i = 0; i < count; i++) {
            NSString *const *slot = (NSString *const *)dlsym(RTLD_DEFAULT, expected[i].name);
            if (slot == NULL) { printf("FAIL: %s is not exported\n", expected[i].name); failures++; continue; }
            NSString *value = *slot;
            if (![value isKindOfClass:[NSString class]] || strcmp([value UTF8String], expected[i].value) != 0) {
                printf("FAIL: %s is \"%s\", expected \"%s\"\n", expected[i].name,
                       [value isKindOfClass:[NSString class]] ? [value UTF8String] : "(not a string)", expected[i].value);
                failures++; continue;
            }
            if (strncmp(expected[i].name, "kCAFilter", 9) == 0) {
                CAFilter *filter = [NSClassFromString(@"CAFilter") filterWithType:value];
                if (filter == nil || ![[filter type] isEqualToString:value]) {
                    printf("FAIL: a filter of type %s keeps its type\n", expected[i].name); failures++;
                }
            }
        }
    }
    if (failures == 0) printf("PASS: %d QuartzCore constants with the observed values\n", count);
    return failures ? 1 : 0;
}
