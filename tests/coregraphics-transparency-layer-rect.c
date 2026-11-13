#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

// CGContextBeginTransparencyLayerWithRect (CGContext.h, macOS 10.5): a transparency layer bounded by a rectangle.
// Drawing inside a layer, then ending it, composites the layer into the context; the rectangle only bounds it.
int main(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char pixels[8 * 8 * 4];
    memset(pixels, 0, sizeof pixels);
    CGContextRef context = CGBitmapContextCreate(pixels, 8, 8, 8, 8 * 4, space, kCGImageAlphaPremultipliedLast);
    if (!context) { printf("FAIL: no bitmap context\n"); return 1; }

    CGContextBeginTransparencyLayerWithRect(context, CGRectMake(0, 0, 8, 8), NULL);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 8, 8));
    CGContextEndTransparencyLayer(context);

    int red = pixels[0] == 255 && pixels[1] == 0 && pixels[2] == 0 && pixels[3] == 255;
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    if (!red) { printf("FAIL: the layer did not composite its fill (%u %u %u %u)\n", pixels[0], pixels[1], pixels[2], pixels[3]); return 2; }
    printf("PASS: transparency layer with rect\n");
    return 0;
}
