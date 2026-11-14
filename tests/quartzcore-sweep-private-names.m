#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// Private QuartzCore names that Freeform, Photos, Podcasts, Journal, Mail and FindMy import. Each string value is
// a GUESS in the implementation, so the test pins none: every constant must be exported, be a non-empty
// NSString, and differ from every other. CAPortalLayer must exist, be a CALayer and work as one.
int main(void) {
    static const char *names[] = {
        "kCAAnimationAbsolute",
        "kCASnapshotBottomLeftOrigin",
        "kCASnapshotContextId",
        "kCASnapshotDestination",
        "kCASnapshotDisplayName",
        "kCASnapshotIgnoreRootAccessibilityFilters",
        "kCASnapshotLayerId",
        "kCASnapshotMode",
        "kCASnapshotModeLayer",
        "kCASnapshotReuseBackdropContents",
        "kCASnapshotTransform",
        "kCAContextIgnoresHitTest",
        "kCAContextDisplayName",
        "kCAPackageTypeArchive",
        "kCAContentsScalingRepeat",
        "kCAContentsFormatRGBA8ColorRGBA8LinearGlyphMask",
        // Existing names the new ones must differ from.
        "kCAAnimationLinear", "kCAFilterGaussianBlur",
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
    if (failures == 0) printf("PASS: %d private QuartzCore names\n", count);
    return failures ? 1 : 0;
}
