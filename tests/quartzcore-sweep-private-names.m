#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// Private QuartzCore names that Freeform, Photos, Podcasts, Journal, Mail and FindMy import. The expected values are
// what a real Mac printed (macOS 26.1, probe 12 section 1, darling_probe12.txt lines 3-18); kCASnapshotDisplayName
// and kCAContextDisplayName legitimately share a value. CAPortalLayer must exist, be a CALayer and work as one; its
// superclass was not observed (GUESS).
int main(void) {
    static const struct { const char *name; const char *value; } expected[] = {
        {"kCAAnimationAbsolute", "absolute"},
        {"kCASnapshotBottomLeftOrigin", "bottomLeftOrigin"},
        {"kCASnapshotContextId", "contextId"},
        {"kCASnapshotDestination", "destination"},
        {"kCASnapshotDisplayName", "displayName"},
        {"kCASnapshotIgnoreRootAccessibilityFilters", "ignoreAccessibility"},
        {"kCASnapshotLayerId", "layerId"},
        {"kCASnapshotMode", "mode"},
        {"kCASnapshotModeLayer", "modeLayer"},
        {"kCASnapshotReuseBackdropContents", "reuseBackdrops"},
        {"kCASnapshotTransform", "transform"},
        {"kCAContextIgnoresHitTest", "ignoresHitTest"},
        {"kCAContextDisplayName", "displayName"},
        {"kCAPackageTypeArchive", "com.apple.coreanimation-archive"},
        {"kCAContentsScalingRepeat", "repeat"},
        {"kCAContentsFormatRGBA8ColorRGBA8LinearGlyphMask", "RGBA8ColorRGBA8Mask"},
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
                failures++;
            }
        }
        Class portal = NSClassFromString(@"CAPortalLayer");
        if (portal == Nil || ![portal isSubclassOfClass:[CALayer class]]) {
            printf("FAIL: CAPortalLayer is a CALayer subclass\n"); failures++;
        } else {
            CALayer *layer = [portal layer];
            layer.opacity = 0.5;
            if (layer == nil || layer.opacity != 0.5) { printf("FAIL: CAPortalLayer works as a layer\n"); failures++; }
        }
    }
    if (failures == 0) printf("PASS: %d private QuartzCore names with the observed values\n", count);
    return failures ? 1 : 0;
}
