#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

#define CHECK(cond, code)                                   \
    do {                                                    \
        if (!(cond)) {                                      \
            fprintf(stderr, "FAIL %d: %s\n", code, #cond);  \
            return code;                                    \
        }                                                   \
    } while (0)

// CATiledLayer is public and Books imports it. The class is looked up by name so the same binary runs against an
// image that lacks it. The defaults checked are the documented ones.
int main(void) {
    @autoreleasepool {
        Class tiledClass = NSClassFromString(@"CATiledLayer");
        CHECK(tiledClass != Nil, 1);
        CHECK([tiledClass isSubclassOfClass: [CALayer class]], 2);
        CHECK([(id) tiledClass fadeDuration] == 0.25, 3);

        CATiledLayer *layer = [tiledClass layer];
        CHECK(layer.tileSize.width == 256 && layer.tileSize.height == 256, 4);
        CHECK(layer.levelsOfDetail == 1, 5);
        CHECK(layer.levelsOfDetailBias == 0, 6);

        layer.tileSize = CGSizeMake(64, 32);
        layer.levelsOfDetail = 3;
        layer.levelsOfDetailBias = 2;
        CHECK(layer.tileSize.width == 64 && layer.tileSize.height == 32, 7);
        CHECK(layer.levelsOfDetail == 3 && layer.levelsOfDetailBias == 2, 8);

        // The presentation copy keeps the three properties.
        CATiledLayer *copy = [[tiledClass alloc] initWithLayer: layer];
        CHECK(copy.tileSize.width == 64 && copy.tileSize.height == 32, 9);
        CHECK(copy.levelsOfDetail == 3 && copy.levelsOfDetailBias == 2, 10);
        [copy release];

        // A layer of another class gives a copy the defaults.
        CATiledLayer *plain = [[tiledClass alloc] initWithLayer: [CALayer layer]];
        CHECK(plain.tileSize.width == 256 && plain.levelsOfDetail == 1 && plain.levelsOfDetailBias == 0, 11);
        [plain release];

        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: layer requiringSecureCoding: YES error: &error];
        CHECK(data != nil, 12);
        CATiledLayer *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass: [CALayer class] fromData: data error: &error];
        CHECK([decoded isKindOfClass: tiledClass], 13);
        CHECK(decoded.tileSize.width == 64 && decoded.tileSize.height == 32, 14);
        CHECK(decoded.levelsOfDetail == 3 && decoded.levelsOfDetailBias == 2, 15);
    }
    printf("PASS: CATiledLayer\n");
    return 0;
}
