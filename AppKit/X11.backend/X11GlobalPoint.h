/* The two conversions between X root pixels and the global point space the X11 backend shares with its callers.
 *
 * -[X11Display mouseLocation] reports the pointer, and -[X11Display warpMouse:] (CGWarpMouseCursorPosition) takes a
 * target, both in points. Everything that moves between root pixels and those points goes through these two
 * functions, so the pointer, the frozen relative-mode cursor and a warp stay in one space and
 * CGWarpMouseCursorPosition(mouseLocation) lands on the pointer. Where the space has its origin and which way y
 * grows is decided here and nowhere else.
 *
 * Plain C so tests/x11-relative-mouse-x11.c can check the round trip on the host. */
#ifndef X11_GLOBAL_POINT_H
#define X11_GLOBAL_POINT_H

#include <math.h>

/* Root pixels (origin at the root window's top-left, y down) to the point -mouseLocation reports. */
static inline void X11PointerLocationFromRoot(double rootX, double rootY, double scale, double *x, double *y) {
    *x = rootX / scale;
    *y = rootY / scale;
}

/* A warp target in points to root pixels, the inverse of X11PointerLocationFromRoot up to rounding to whole pixels. */
static inline void X11RootFromWarpTarget(double x, double y, double scale, int *rootX, int *rootY) {
    *rootX = (int) lround(x * scale);
    *rootY = (int) lround(y * scale);
}

#endif
