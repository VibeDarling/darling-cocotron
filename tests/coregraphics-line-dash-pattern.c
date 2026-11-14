#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

// CGContextGetLineDashPattern is private (Calendar imports it). The expected values for the first three cases are
// what a real Mac wrote into two scratch buffers (macOS 26.1, probe 11 section 4, darling_probe11.txt lines 56-65):
// the dash phase into the first, the dash lengths into the second, and nothing else; a context with no dash writes
// phase 0 and no lengths. GUESS: the save, change, restore case (phase 4) was never probed on the Mac; the probe's
// save/restore (line 66) checked only the count. Also not probed: a context with a nonzero phase and count 0
// (Cocotron then writes that phase).
// The return value is unknown (masked in the probe), so it is declared void and never read.
typedef void (*PatternFn)(CGContextRef, CGFloat *, CGFloat *);
typedef size_t (*CountFn)(CGContextRef);

#define SENTINEL_A (-111.0)
#define SENTINEL_B (-222.0)

static int check(const char *label, PatternFn pattern, CGContextRef context, double phase, const double *lengths, size_t count) {
    CGFloat a[8], b[8];
    for (int i = 0; i < 8; i++) { a[i] = SENTINEL_A; b[i] = SENTINEL_B; }
    pattern(context, a, b);
    int bad = a[0] != phase;
    for (int i = 1; i < 8; i++) bad |= a[i] != SENTINEL_A;
    for (size_t i = 0; i < 8; i++) bad |= b[i] != (i < count ? lengths[i] : SENTINEL_B);
    if (bad) printf("FAIL: %s: phase buffer %g %g, lengths buffer %g %g %g %g\n", label, a[0], a[1], b[0], b[1], b[2], b[3]);
    return bad;
}

int main(void) {
    PatternFn pattern = (PatternFn) dlsym(RTLD_DEFAULT, "CGContextGetLineDashPattern");
    CountFn count = (CountFn) dlsym(RTLD_DEFAULT, "CGContextGetLineDashCount");
    if (pattern == NULL) { printf("FAIL: CGContextGetLineDashPattern is exported\n"); return 1; }
    if (count == NULL) { printf("FAIL: CGContextGetLineDashCount is exported\n"); return 1; }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 8, 8, 8, 0, space, kCGImageAlphaPremultipliedLast);
    int failures = 0;
    CGFloat dashes[3] = {3, 5, 7};
    static const double three[] = {3, 5, 7}, two[] = {3, 5};
    CGContextSetLineDash(context, 2, dashes, 3);
    failures += check("phase 2, three lengths", pattern, context, 2, three, 3);
    CGContextSetLineDash(context, 0, NULL, 0);
    failures += check("no dash", pattern, context, 0, NULL, 0);
    CGContextSetLineDash(context, 1.5, dashes, 2);
    failures += check("phase 1.5, two lengths", pattern, context, 1.5, two, 2);
    CGContextSetLineDash(context, 4, dashes, 3);
    CGContextSaveGState(context);
    CGContextSetLineDash(context, 0, dashes, 1);
    CGContextRestoreGState(context);
    failures += check("after save, change, restore", pattern, context, 4, three, 3);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    if (failures == 0) printf("PASS: CGContextGetLineDashPattern\n");
    return failures ? 1 : 0;
}
