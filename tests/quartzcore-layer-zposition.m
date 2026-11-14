// CALayer.zPosition is public API (default 0). Apps subclass CALayer and set it (AirPort Utility's NetTopoInternetLayer died
// with -[NetTopoInternetLayer setZPosition:] unrecognized selector). It must be stored, copied and archived.
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

#define CHECK(cond, code)                                   \
    do {                                                    \
        if (!(cond)) {                                      \
            fprintf(stderr, "FAIL %d: %s\n", code, #cond);  \
            return code;                                    \
        }                                                   \
    } while (0)

@interface ZLayerSubclass : CALayer
@end
@implementation ZLayerSubclass
@end

int main(void) {
    @autoreleasepool {
        CALayer *layer = [CALayer layer];
        CHECK([layer respondsToSelector: @selector(zPosition)], 1);
        CHECK([layer respondsToSelector: @selector(setZPosition:)], 2);
        CHECK([layer zPosition] == 0, 3);
        layer.zPosition = 7.5;
        CHECK(layer.zPosition == 7.5, 4);

        ZLayerSubclass *sub = [ZLayerSubclass layer];
        [sub setZPosition: -2];
        CHECK([sub zPosition] == -2, 5);

        CALayer *copy = [[CALayer alloc] initWithLayer: layer];
        CHECK(copy.zPosition == 7.5, 6);
        [copy release];

        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: layer requiringSecureCoding: YES error: &error];
        CHECK(data != nil, 7);
        CALayer *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass: [CALayer class] fromData: data error: &error];
        CHECK(decoded != nil, 8);
        CHECK(decoded.zPosition == 7.5, 9);
    }
    printf("PASS\n");
    return 0;
}
