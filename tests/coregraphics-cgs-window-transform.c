#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/CGSServerSPI.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>

// CGSSetWindowTransform is private (Calendar imports it); the prototype is the one sequelpro's PSMTabDragAssistant.h
// declares. In this implementation it is the At-placement call with placement 0 and reserved 0 (GUESS). No window
// exists in this process, so the test can only reach the error path: the identifier cannot name a window, and the
// call must give the same illegal-argument answer as the At-placement form, not a success and not an abort. The
// success path needs a window and a display and is not covered here.
typedef CGError (*SetFn)(CGSConnectionID, uint32_t, CGAffineTransform);
typedef CGError (*SetAtFn)(CGSConnectionID, uint32_t, int32_t, int32_t, CGAffineTransform);

int main(void) {
    SetFn set = (SetFn) dlsym(RTLD_DEFAULT, "CGSSetWindowTransform");
    SetAtFn setAt = (SetAtFn) dlsym(RTLD_DEFAULT, "CGSSetWindowTransformAtPlacement");
    if (set == NULL) { printf("FAIL: CGSSetWindowTransform is exported\n"); return 1; }
    if (setAt == NULL) { printf("FAIL: CGSSetWindowTransformAtPlacement is exported\n"); return 1; }
    CGSConnectionID cid = CGSMainConnectionID();
    CGAffineTransform scale = CGAffineTransformMakeScale(2, 3);
    CGError got = set(cid, UINT32_MAX, scale);
    CGError expected = setAt(cid, UINT32_MAX, 0, 0, scale);
    printf("set %d, at-placement %d\n", (int) got, (int) expected);
    if (got != kCGErrorIllegalArgument) { printf("FAIL: an unknown window is an illegal argument\n"); return 1; }
    if (got != expected) { printf("FAIL: same answer as the At-placement form\n"); return 1; }
    printf("PASS: CGSSetWindowTransform\n");
    return 0;
}
