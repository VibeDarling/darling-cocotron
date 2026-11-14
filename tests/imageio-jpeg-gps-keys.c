#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// An APP1 Exif segment (marker included) made for this test: its IFD0 points to a GPS IFD (LatitudeRef "N", Latitude 37 30 0,
// LongitudeRef "E", Longitude 122 15 0, Altitude 100). The tags are the EXIF GPS tags 1, 2, 3, 4 and 6. It is inserted
// after the SOI of a JPEG the encoder makes, because the JPEG source needs a decodable image to give properties.
static const unsigned char app1[] = {
    0xff, 0xe1, 0x00, 0x9c, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x4d, 0x4d,
    0x00, 0x2a, 0x00, 0x00, 0x00, 0x08, 0x00, 0x01, 0x88, 0x25, 0x00, 0x04,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1a, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x05, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x4e, 0x00,
    0x00, 0x00, 0x00, 0x02, 0x00, 0x05, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
    0x00, 0x5c, 0x00, 0x03, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x45, 0x00,
    0x00, 0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00,
    0x00, 0x74, 0x00, 0x06, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x8c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x25, 0x00, 0x00,
    0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x7a, 0x00, 0x00,
    0x00, 0x01, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00,
    0x00, 0x01
};

static int stringIs(CFTypeRef value, const char *expected) {
    char buffer[16];
    return value != NULL && CFGetTypeID(value) == CFStringGetTypeID() &&
           CFStringGetCString(value, buffer, sizeof buffer, kCFStringEncodingUTF8) && strcmp(buffer, expected) == 0;
}

static int degrees(CFTypeRef value, double d, double m, double s) {
    double v[3];
    if (value == NULL || CFGetTypeID(value) != CFArrayGetTypeID() || CFArrayGetCount(value) != 3) return 0;
    for (int i = 0; i < 3; i++) {
        CFTypeRef n = CFArrayGetValueAtIndex(value, i);
        if (CFGetTypeID(n) != CFNumberGetTypeID() || !CFNumberGetValue(n, kCFNumberDoubleType, &v[i])) return 0;
    }
    return v[0] == d && v[1] == m && v[2] == s;
}

// The {GPS} dictionary of a JPEG is keyed like ImageIO's on a real Mac, where kCGImagePropertyGPSLatitude is "Latitude" and
// its siblings are "LatitudeRef", "Longitude", "LongitudeRef" and "Altitude" (mac-probe/symbols_e_probe1.txt:22-27). The
// strings are written out here, not taken from the constants, so the decoder and the constants are checked independently.
int main(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 8, 8, 8, 0, space, kCGImageAlphaPremultipliedLast);
    EXPECT(context != NULL, "a bitmap context");
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 8, 8));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CFMutableDataRef plain = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(plain, CFSTR("public.jpeg"), 1, NULL);
    EXPECT(destination != NULL, "a JPEG destination");
    CGImageDestinationAddImage(destination, image, NULL);
    EXPECT(CGImageDestinationFinalize(destination), "the JPEG is encoded");
    EXPECT(CFDataGetLength(plain) > 2 && CFDataGetBytePtr(plain)[0] == 0xff && CFDataGetBytePtr(plain)[1] == 0xd8, "it starts with SOI");
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    CFDataAppendBytes(data, CFDataGetBytePtr(plain), 2);
    CFDataAppendBytes(data, app1, sizeof app1);
    CFDataAppendBytes(data, CFDataGetBytePtr(plain) + 2, CFDataGetLength(plain) - 2);
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    EXPECT(source != NULL, "the JPEG opens");
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    EXPECT(properties != NULL, "the properties exist");
    CFDictionaryRef gps = CFDictionaryGetValue(properties, CFSTR("{GPS}"));
    EXPECT(gps != NULL && CFGetTypeID(gps) == CFDictionaryGetTypeID(), "the {GPS} dictionary exists");
    EXPECT(stringIs(CFDictionaryGetValue(gps, CFSTR("LatitudeRef")), "N"), "LatitudeRef is N");
    EXPECT(degrees(CFDictionaryGetValue(gps, CFSTR("Latitude")), 37, 30, 0), "Latitude is 37 30 0");
    EXPECT(stringIs(CFDictionaryGetValue(gps, CFSTR("LongitudeRef")), "E"), "LongitudeRef is E");
    EXPECT(degrees(CFDictionaryGetValue(gps, CFSTR("Longitude")), 122, 15, 0), "Longitude is 122 15 0");
    double altitude = 0;
    CFTypeRef value = CFDictionaryGetValue(gps, CFSTR("Altitude"));
    EXPECT(value != NULL && CFGetTypeID(value) == CFNumberGetTypeID() && CFNumberGetValue(value, kCFNumberDoubleType, &altitude) && altitude == 100, "Altitude is 100");
    EXPECT(CFDictionaryGetValue(gps, CFSTR("GPSLatitude")) == NULL && CFDictionaryGetValue(gps, CFSTR("GPSAltitude")) == NULL,
           "the raw tag names are not used");
    CFRelease(properties);
    CFRelease(source);
    CFRelease(data);
    printf("PASS: JPEG GPS dictionary keys\n");
    return 0;
}
