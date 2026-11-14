#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// Books and App Store import these private QuartzCore string constants (the names WebKit declares, plus the
// others the sweep listed). The test finds each through dlsym so one binary runs against an image that lacks
// them. The string values are a GUESS in the implementation, so the test does not pin them: it checks that every
// new name is exported, is a non-empty string, differs from every other new value and from every existing
// QuartzCore string constant, and works as a filter type.
@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@property(readonly, copy) NSString *type;
@end

int main(void) {
    static const char *names[] = {
        "kCAFilterPlusD",
        "kCAFilterPlusL",
        "kCAFilterColorBlendMode",
        "kCAFilterColorBurnBlendMode",
        "kCAFilterColorDodgeBlendMode",
        "kCAFilterDarkenBlendMode",
        "kCAFilterDarkenSourceOver",
        "kCAFilterDestOut",
        "kCAFilterDifferenceBlendMode",
        "kCAFilterDivideBlendMode",
        "kCAFilterExclusionBlendMode",
        "kCAFilterHardLightBlendMode",
        "kCAFilterHueBlendMode",
        "kCAFilterLightenBlendMode",
        "kCAFilterLightenSourceOver",
        "kCAFilterLinearBurnBlendMode",
        "kCAFilterLinearDodgeBlendMode",
        "kCAFilterLinearLightBlendMode",
        "kCAFilterLuminosityBlendMode",
        "kCAFilterMaximum",
        "kCAFilterMinimum",
        "kCAFilterMultiply",
        "kCAFilterNormalBlendMode",
        "kCAFilterOverlayBlendMode",
        "kCAFilterPinLightBlendMode",
        "kCAFilterSaturationBlendMode",
        "kCAFilterScreenBlendMode",
        "kCAFilterSoftLightBlendMode",
        "kCAFilterSubtractBlendMode",
        "kCAFilterSubtractD",
        "kCAFilterSubtractS",
        "kCAContentsFormatA8",
        "kCALayerContentsSwizzleAAAA",
        "kCALayerContentsSwizzleRGBA",
    };
    // Every string constant QuartzCore defines at the base commit. A new value must differ from each of them,
    // so a new name cannot silently alias an existing type, gravity, format or key. Two existing names may share a
    // value with each other (kCALineCapRound and kCALineJoinRound); that is not checked.
    static const char *existing[] = {
        "kCAFilterMultiplyBlendMode",
        "kCAAlignmentCenter",
        "kCAAlignmentJustified",
        "kCAAlignmentLeft",
        "kCAAlignmentNatural",
        "kCAAlignmentRight",
        "kCAAnimationCubic",
        "kCAAnimationCubicPaced",
        "kCAAnimationDiscrete",
        "kCAAnimationLinear",
        "kCAAnimationPaced",
        "kCAAnimationRotateAuto",
        "kCAAnimationRotateAutoReverse",
        "kCAContentsFormatAutomatic",
        "kCAContentsFormatGray8Uint",
        "kCAContentsFormatRGBA16Float",
        "kCAContentsFormatRGBA8Uint",
        "kCACornerCurveCircular",
        "kCACornerCurveContinuous",
        "kCAEmitterLayerAdditive",
        "kCAEmitterLayerBackToFront",
        "kCAEmitterLayerCircle",
        "kCAEmitterLayerCuboid",
        "kCAEmitterLayerLine",
        "kCAEmitterLayerOldestFirst",
        "kCAEmitterLayerOldestLast",
        "kCAEmitterLayerOutline",
        "kCAEmitterLayerPoint",
        "kCAEmitterLayerPoints",
        "kCAEmitterLayerRectangle",
        "kCAEmitterLayerSphere",
        "kCAEmitterLayerSurface",
        "kCAEmitterLayerUnordered",
        "kCAEmitterLayerVolume",
        "kCAFillModeBackwards",
        "kCAFillModeBoth",
        "kCAFillModeForwards",
        "kCAFillModeRemoved",
        "kCAFillRuleEvenOdd",
        "kCAFillRuleNonZero",
        "kCAFilterAlphaThreshold",
        "kCAFilterAverageColor",
        "kCAFilterColorBrightness",
        "kCAFilterColorContrast",
        "kCAFilterColorHueRotate",
        "kCAFilterColorInvert",
        "kCAFilterColorMatrix",
        "kCAFilterColorMonochrome",
        "kCAFilterColorSaturate",
        "kCAFilterCurves",
        "kCAFilterGaussianBlur",
        "kCAFilterInputAlphaValues",
        "kCAFilterInputAmount",
        "kCAFilterInputAngle",
        "kCAFilterInputBias",
        "kCAFilterInputBlueValues",
        "kCAFilterInputColor",
        "kCAFilterInputColorMatrix",
        "kCAFilterInputDither",
        "kCAFilterInputGreenValues",
        "kCAFilterInputHardEdges",
        "kCAFilterInputNormalizeEdges",
        "kCAFilterInputPremultipliedValues",
        "kCAFilterInputRadius",
        "kCAFilterInputRedValues",
        "kCAFilterInputValues",
        "kCAFilterLinear",
        "kCAFilterLuminanceCurveMap",
        "kCAFilterLuminanceToAlpha",
        "kCAFilterMultiplyColor",
        "kCAFilterNearest",
        "kCAFilterTrilinear",
        "kCAFilterVariableBlur",
        "kCAFilterVibrantColorMatrix",
        "kCAGradientLayerAxial",
        "kCAGradientLayerConic",
        "kCAGradientLayerRadial",
        "kCAGravityBottom",
        "kCAGravityBottomLeft",
        "kCAGravityBottomRight",
        "kCAGravityCenter",
        "kCAGravityLeft",
        "kCAGravityResize",
        "kCAGravityResizeAspect",
        "kCAGravityResizeAspectFill",
        "kCAGravityRight",
        "kCAGravityTop",
        "kCAGravityTopLeft",
        "kCAGravityTopRight",
        "kCALineCapButt",
        "kCALineCapRound",
        "kCALineCapSquare",
        "kCALineJoinBevel",
        "kCALineJoinMiter",
        "kCALineJoinRound",
        "kCAMediaTimingFunctionEaseIn",
        "kCAMediaTimingFunctionLinear",
        "kCAOnOrderIn",
        "kCAOnOrderOut",
        "kCARendererColorSpace",
        "kCAScrollBoth",
        "kCAScrollHorizontally",
        "kCAScrollNone",
        "kCAScrollVertically",
        "kCATransactionDisableActions",
        "kCATransition",
        "kCATransitionFade",
        "kCATransitionFromBottom",
        "kCATransitionFromLeft",
        "kCATransitionFromRight",
        "kCATransitionFromTop",
        "kCATransitionMoveIn",
        "kCATransitionPush",
        "kCATransitionReveal",
        "kCATruncationEnd",
        "kCATruncationMiddle",
        "kCATruncationNone",
        "kCATruncationStart",
        "kCAValueFunctionRotateX",
        "kCAValueFunctionRotateY",
        "kCAValueFunctionRotateZ",
        "kCAValueFunctionScale",
        "kCAValueFunctionScaleX",
        "kCAValueFunctionScaleY",
        "kCAValueFunctionScaleZ",
        "kCAValueFunctionTranslate",
        "kCAValueFunctionTranslateX",
        "kCAValueFunctionTranslateY",
        "kCAValueFunctionTranslateZ",
    };
    int count = (int)(sizeof names / sizeof names[0]);
    int existingCount = (int)(sizeof existing / sizeof existing[0]);
    int failures = 0;
    @autoreleasepool {
        NSMutableDictionary *seen = [NSMutableDictionary dictionary];
        for (int i = 0; i < existingCount; i++) {
            NSString *const *slot = (NSString *const *)dlsym(RTLD_DEFAULT, existing[i]);
            if (slot == NULL || ![*slot isKindOfClass:[NSString class]]) {
                printf("FAIL: existing %s is not an exported string\n", existing[i]); failures++; continue;
            }
            seen[*slot] = [NSString stringWithUTF8String:existing[i]];
        }
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
    if (failures == 0) printf("PASS: %d new QuartzCore constants, distinct from %d existing\n", count, existingCount);
    return failures ? 1 : 0;
}
