#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// Books and App Store import these private QuartzCore string constants (the names WebKit declares, plus the
// others the sweep listed). The test finds each through dlsym so one binary runs against an image that lacks
// them. The string values are a GUESS in the implementation, so the test does not pin them: it checks that every
// name is exported, is a non-empty string, differs from every other name's value, and works as a filter type.
@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@property(readonly, copy) NSString *type;
@end

int main(void) {
    static const char *names[] = {
        "kCAFilterPlusD", "kCAFilterPlusL", "kCAFilterColorBlendMode", "kCAFilterColorBurnBlendMode",
        "kCAFilterColorDodgeBlendMode", "kCAFilterDarkenBlendMode", "kCAFilterDarkenSourceOver", "kCAFilterDestOut",
        "kCAFilterDifferenceBlendMode", "kCAFilterDivideBlendMode", "kCAFilterExclusionBlendMode",
        "kCAFilterHardLightBlendMode", "kCAFilterHueBlendMode", "kCAFilterLightenBlendMode",
        "kCAFilterLightenSourceOver", "kCAFilterLinearBurnBlendMode", "kCAFilterLinearDodgeBlendMode",
        "kCAFilterLinearLightBlendMode", "kCAFilterLuminosityBlendMode", "kCAFilterMaximum", "kCAFilterMinimum",
        "kCAFilterMultiply", "kCAFilterMultiplyBlendMode", "kCAFilterNormalBlendMode", "kCAFilterOverlayBlendMode",
        "kCAFilterPinLightBlendMode", "kCAFilterSaturationBlendMode", "kCAFilterScreenBlendMode",
        "kCAFilterSoftLightBlendMode", "kCAFilterSubtractBlendMode", "kCAFilterSubtractD", "kCAFilterSubtractS",
        "kCAContentsFormatA8", "kCALayerContentsSwizzleAAAA", "kCALayerContentsSwizzleRGBA",
        // Existing names the new ones must not collide with.
        "kCAFilterGaussianBlur", "kCAContentsFormatGray8Uint",
    };
    int count = (int)(sizeof names / sizeof names[0]);
    int failures = 0;
    @autoreleasepool {
        NSMutableDictionary *seen = [NSMutableDictionary dictionary];
        for (int i = 0; i < count; i++) {
            NSString *const *slot = (NSString *const *)dlsym(RTLD_DEFAULT, names[i]);
            if (slot == NULL) { printf("FAIL: %s is not exported\n", names[i]); failures++; continue; }
            NSString *value = *slot;
            if (![value isKindOfClass:[NSString class]] || [value length] == 0) {
                printf("FAIL: %s is not a non-empty string\n", names[i]); failures++; continue;
            }
            NSString *other = seen[value];
            if (other != nil) { printf("FAIL: %s and %s share a value\n", names[i], [other UTF8String]); failures++; }
            seen[value] = [NSString stringWithUTF8String:names[i]];
            if (strncmp(names[i], "kCAFilter", 9) == 0) {
                CAFilter *filter = [NSClassFromString(@"CAFilter") filterWithType:value];
                if (filter == nil || ![[filter type] isEqualToString:value]) {
                    printf("FAIL: a filter of type %s keeps its type\n", names[i]); failures++;
                }
            }
        }
    }
    if (failures == 0) printf("PASS: %d QuartzCore constants\n", count);
    return failures ? 1 : 0;
}
