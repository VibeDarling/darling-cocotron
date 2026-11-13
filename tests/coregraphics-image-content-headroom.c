#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGImageCreateCopyWithContentHeadroom (macOS 15.0): a copy of the image tagged with a content headroom.
// Cocotron has no HDR, so the headroom has no effect: the result is CGImageCreateCopy of the image (an immutable
// image may come back as the same object, retained), so it has the same size and format.
int main(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char pixels[4 * 4 * 4];
    memset(pixels, 0x7f, sizeof pixels);
    CGContextRef context = CGBitmapContextCreate(pixels, 4, 4, 8, 16, space, kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(context);
    EXPECT(image != NULL, "a source image");

    CGImageRef copy = CGImageCreateCopyWithContentHeadroom(2.0f, image);
    EXPECT(copy != NULL, "a copy is returned");
    EXPECT(CGImageGetWidth(copy) == 4 && CGImageGetHeight(copy) == 4, "the copy keeps the size");
    EXPECT(CGImageGetBitsPerComponent(copy) == CGImageGetBitsPerComponent(image), "the copy keeps the pixel format");
    CGImageRef plain = CGImageCreateCopy(image);
    EXPECT((plain == image) == (copy == image), "it answers as CGImageCreateCopy does");
    CGImageRelease(plain);
    CGImageRelease(copy);
    EXPECT(CGImageGetWidth(image) == 4, "releasing the copy leaves the source alive");
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    printf("PASS: image content headroom\n");
    return 0;
}
