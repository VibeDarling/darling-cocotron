#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

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

// The {GPS} dictionary of a JPEG is keyed like ImageIO's on a real Mac, where kCGImagePropertyGPSLatitude is "Latitude" and
// its siblings are "LatitudeRef", "Longitude", "LongitudeRef" and "Altitude" (probe line 22-27). The strings are written out
// here, not taken from the constants, so the decoder and the constants are checked independently. Only the keys are pinned:
// the value types and the Ref convention are NEEDS-REAL-MAC (the decoder returns the raw EXIF values).
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
    const char *labels[] = { "LatitudeRef", "Latitude", "LongitudeRef", "Longitude", "Altitude" };
    for (int i = 0; i < 5; i++) {
        char message[48];
        snprintf(message, sizeof message, "%s is present", labels[i]);
        CFStringRef label = CFStringCreateWithCString(NULL, labels[i], kCFStringEncodingUTF8);
        EXPECT(CFDictionaryGetValue(gps, label) != NULL, message);
        CFRelease(label);
    }
    EXPECT(CFDictionaryGetValue(gps, CFSTR("GPSLatitude")) == NULL && CFDictionaryGetValue(gps, CFSTR("GPSAltitude")) == NULL,
           "the raw tag names are not used");
    CFRelease(properties);
    CFRelease(source);
    CFRelease(data);
    printf("PASS: JPEG GPS dictionary keys\n");
    return 0;
}
