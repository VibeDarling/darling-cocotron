#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>

// CATransform3DGetAffineTransform is public and Freeform imports it. It is found through dlsym so one binary runs
// against an image that lacks it. It is the inverse of CATransform3DMakeAffineTransform, which maps
// a, b, c, d, tx, ty to m11, m12, m21, m22, m41, m42.
typedef CGAffineTransform (*GetAffineFn)(CATransform3D);

int main(void) {
    GetAffineFn get = (GetAffineFn) dlsym(RTLD_DEFAULT, "CATransform3DGetAffineTransform");
    if (get == NULL) { printf("FAIL: CATransform3DGetAffineTransform is exported\n"); return 1; }
    int failures = 0;

    CGAffineTransform in = CGAffineTransformMake(1.5, 2.5, -3.5, 4.5, 5.5, -6.5);
    CGAffineTransform out = get(CATransform3DMakeAffineTransform(in));
    if (!CGAffineTransformEqualToTransform(in, out)) { printf("FAIL: round trip\n"); failures++; }

    out = get(CATransform3DIdentity);
    if (!CGAffineTransformIsIdentity(out)) { printf("FAIL: identity\n"); failures++; }

    // Each of the six components goes to its own slot: distinct values catch a swap.
    CATransform3D t = CATransform3DIdentity;
    t.m11 = 11; t.m12 = 12; t.m21 = 21; t.m22 = 22; t.m41 = 41; t.m42 = 42;
    t.m13 = 13; t.m31 = 31; t.m33 = 33; t.m43 = 43; t.m14 = 14; t.m44 = 44;
    out = get(t);
    if (out.a != 11 || out.b != 12 || out.c != 21 || out.d != 22 || out.tx != 41 || out.ty != 42) {
        printf("FAIL: components (%g %g %g %g %g %g)\n", out.a, out.b, out.c, out.d, out.tx, out.ty);
        failures++;
    }
    if (failures == 0) printf("PASS: CATransform3DGetAffineTransform\n");
    return failures ? 1 : 0;
}
