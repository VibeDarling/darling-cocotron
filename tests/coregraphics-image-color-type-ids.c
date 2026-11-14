#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

// CGImageGetTypeID and CGColorGetTypeID are public (Photos, ColorSync Utility and Freeform import them). They are
// looked up with dlsym so one binary runs against an image that lacks them. The documented contract: the type ID
// of an instance is what CFGetTypeID reports, and the two types differ from each other and from CGFont's.
typedef CFTypeID (*TypeIDFn)(void);

int main(void) {
    TypeIDFn imageType = (TypeIDFn) dlsym(RTLD_DEFAULT, "CGImageGetTypeID");
    TypeIDFn colorType = (TypeIDFn) dlsym(RTLD_DEFAULT, "CGColorGetTypeID");
    if (imageType == NULL) { printf("FAIL: CGImageGetTypeID is exported\n"); return 1; }
    if (colorType == NULL) { printf("FAIL: CGColorGetTypeID is exported\n"); return 1; }

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, 8, 8, space, kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGColorRef color = CGColorCreateGenericRGB(0.1, 0.2, 0.3, 1);
    int failures = 0;
    if (image == NULL || color == NULL) { printf("FAIL: could not create an image and a color\n"); return 1; }
    if (CFGetTypeID(image) != imageType()) { printf("FAIL: CFGetTypeID(image) != CGImageGetTypeID()\n"); failures++; }
    if (CFGetTypeID(color) != colorType()) { printf("FAIL: CFGetTypeID(color) != CGColorGetTypeID()\n"); failures++; }
    if (imageType() == colorType()) { printf("FAIL: image and color share a type ID\n"); failures++; }
    if (imageType() == CGFontGetTypeID() || colorType() == CGFontGetTypeID()) { printf("FAIL: a type ID equals CGFont's\n"); failures++; }
    CGImageRelease(image); CGColorRelease(color); CGContextRelease(context); CGColorSpaceRelease(space);
    if (failures == 0) printf("PASS: CGImageGetTypeID, CGColorGetTypeID\n");
    return failures ? 1 : 0;
}
