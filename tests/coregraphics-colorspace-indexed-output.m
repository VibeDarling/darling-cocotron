#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

// CGColorSpaceSupportsOutput is false for an indexed space on a real Mac (macOS 26.1, probe 12 section 3,
// darling_probe12.txt line 44). Cocotron has no public CGColorSpaceCreateIndexed yet (the sweep lists it), so the
// space is made through Onyx2D's own initializer, -initWithColorSpace:hival:bytes:, which sets the indexed model.
// The function is found through dlsym so one binary runs against an image that lacks it.
@interface NSObject (IndexedColorSpace)
- (id)initWithColorSpace:(CGColorSpaceRef)base hival:(size_t)hival bytes:(const unsigned char *)bytes;
@end

typedef bool (*Query)(CGColorSpaceRef);

int main(void) {
    Query supports = (Query) dlsym(RTLD_DEFAULT, "CGColorSpaceSupportsOutput");
    Query isHDR = (Query) dlsym(RTLD_DEFAULT, "CGColorSpaceIsHDR");
    if (supports == NULL || isHDR == NULL) { printf("FAIL: CGColorSpaceSupportsOutput and CGColorSpaceIsHDR are exported\n"); return 1; }
    Class space = NSClassFromString(@"O2ColorSpace");
    if (space == Nil) { printf("FAIL: O2ColorSpace exists\n"); return 1; }
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    static const unsigned char palette[6] = { 255, 0, 0, 0, 0, 255 };
    CGColorSpaceRef indexed = (CGColorSpaceRef) [[space alloc] initWithColorSpace:rgb hival:1 bytes:palette];
    if (indexed == NULL || CGColorSpaceGetModel(indexed) != kCGColorSpaceModelIndexed) {
        printf("FAIL: an indexed space was made\n"); return 1;
    }
    int failures = 0;
    if (supports(indexed)) { printf("FAIL: an indexed space does not support output\n"); failures++; }
    if (isHDR(indexed)) { printf("FAIL: an indexed space is not HDR\n"); failures++; }
    CGColorSpaceRelease(indexed);
    CGColorSpaceRelease(rgb);
    if (failures == 0) printf("PASS: indexed color space, SupportsOutput false, IsHDR false\n");
    return failures ? 1 : 0;
}
