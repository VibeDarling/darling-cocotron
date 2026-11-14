#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGContextGetLineDashCount is private (no SDK header), so the test finds it through dlsym; Calendar binds it at
// launch. The count is that of the current dash pattern: 0 until a dash is set and again when it is turned off
// (a NULL lengths array or a zero count, per the CGContextSetLineDash documentation), and it follows
// CGContextSaveGState / CGContextRestoreGState.
int main(void) {
    size_t (*getCount)(CGContextRef) = (size_t (*)(CGContextRef)) dlsym(RTLD_DEFAULT, "CGContextGetLineDashCount");
    EXPECT(getCount != NULL, "CGContextGetLineDashCount is exported");

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 4, 4, 8, 0, space, kCGImageAlphaPremultipliedLast);
    EXPECT(context != NULL, "bitmap context");

    EXPECT(getCount(context) == 0, "a new context has no dash");
    CGFloat two[] = {3, 1};
    CGContextSetLineDash(context, 0, two, 2);
    EXPECT(getCount(context) == 2, "two dash lengths");
    CGFloat three[] = {1, 2, 3};
    CGContextSetLineDash(context, 1, three, 3);
    EXPECT(getCount(context) == 3, "three dash lengths replace the two");

    CGContextSaveGState(context);
    CGContextSetLineDash(context, 0, NULL, 0);
    EXPECT(getCount(context) == 0, "a zero count turns dashing off");
    CGContextSetLineDash(context, 0, three, 3);
    CGContextSetLineDash(context, 0, NULL, 2);
    EXPECT(getCount(context) == 0, "a NULL lengths array turns dashing off whatever the count");
    CGContextRestoreGState(context);
    EXPECT(getCount(context) == 3, "restoring the state brings the saved pattern back");

    EXPECT(getCount(NULL) == 0, "a NULL context has no dash");
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    printf("PASS: CGContextGetLineDashCount\n");
    return 0;
}
