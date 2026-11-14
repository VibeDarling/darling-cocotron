#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// The {GPS} dictionary of a JPEG is read like ImageIO's on a real Mac (macOS 26.1; the probe output lines are cited per
// check). The key strings and the expected numbers are written out here, computed by hand, not taken from the decoder.

typedef struct {
    const char *latRef; unsigned lat[3];
    const char *lonRef; unsigned lon[3];
    unsigned altitude;
    int latCount;          // rationals in the Latitude tag, 0 for the usual 3 (a fourth one is 0/1)
    int zeroSecondsDenominator; // the third Latitude rational is n/0
} Sample;

static size_t put(unsigned char *out, size_t at, unsigned long value, int bytes) {
    for (int i = bytes - 1; i >= 0; i--) out[at++] = (value >> (8 * i)) & 0xff;
    return at;
}

static size_t entry(unsigned char *out, size_t at, int tag, int type, int count, unsigned long value) {
    at = put(out, at, tag, 2); at = put(out, at, type, 2); at = put(out, at, count, 4);
    // a value of up to 4 bytes is stored left-aligned in the 4 value bytes; the ASCII and BYTE values are passed that way
    return put(out, at, value, 4);
}

static size_t rationals(unsigned char *out, size_t at, const unsigned v[3], int count, int zeroThird) {
    for (int i = 0; i < count; i++) {
        at = put(out, at, i < 3 ? v[i] : 0, 4);
        at = put(out, at, (zeroThird && i == 2) ? 0 : 1, 4);
    }
    return at;
}

// An APP1 Exif segment, marker included, big-endian TIFF: IFD0 holds only the GPS IFD pointer; the GPS IFD holds the EXIF GPS
// tags 1 (LatitudeRef), 2 (Latitude, three rationals), 3, 4 (the same for the longitude), 5 (AltitudeRef, byte 0) and 6
// (Altitude, one rational). Returns its length.
static size_t makeApp1(const Sample *s, unsigned char *out) {
    unsigned char *tiff = out + 10;
    int latCount = s->latCount ? s->latCount : 3;
    size_t at = 0;
    at = put(tiff, at, 0x4d4d, 2); at = put(tiff, at, 42, 2); at = put(tiff, at, 8, 4);
    at = put(tiff, at, 1, 2); at = entry(tiff, at, 0x8825, 4, 1, 26); at = put(tiff, at, 0, 4);
    at = put(tiff, at, 6, 2);
    at = entry(tiff, at, 1, 2, 2, (unsigned long)s->latRef[0] << 24);
    at = entry(tiff, at, 2, 5, latCount, 104);
    at = entry(tiff, at, 3, 2, 2, (unsigned long)s->lonRef[0] << 24);
    at = entry(tiff, at, 4, 5, 3, 104 + 8 * latCount);
    at = entry(tiff, at, 5, 1, 1, 0);
    at = entry(tiff, at, 6, 5, 1, 104 + 8 * latCount + 24);
    at = put(tiff, at, 0, 4);
    at = rationals(tiff, at, s->lat, latCount, s->zeroSecondsDenominator);
    at = rationals(tiff, at, s->lon, 3, 0);
    at = put(tiff, at, s->altitude, 4); at = put(tiff, at, 1, 4);
    size_t length = 2 + 6 + at;
    put(out, 0, 0xffe1, 2); put(out, 2, length, 2);
    memcpy(out + 4, "Exif\0\0", 6);
    return 2 + length;
}

static int isDouble(CFTypeRef value) {
    return value != NULL && CFGetTypeID(value) == CFNumberGetTypeID() && CFNumberIsFloatType(value) && CFNumberGetByteSize(value) == 8;
}

static int isDoubleNear(CFTypeRef value, double expected) {
    double actual;
    return isDouble(value) && CFNumberGetValue(value, kCFNumberDoubleType, &actual) && fabs(actual - expected) < 1e-9;
}

static int isString(CFTypeRef value, const char *expected) {
    char buffer[8];
    return value != NULL && CFGetTypeID(value) == CFStringGetTypeID() &&
           CFStringGetCString(value, buffer, sizeof buffer, kCFStringEncodingUTF8) && strcmp(buffer, expected) == 0;
}

static CFTypeRef at(CFDictionaryRef d, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFTypeRef v = CFDictionaryGetValue(d, k);
    CFRelease(k);
    return v;
}

static CFDictionaryRef gpsOf(CFDataRef jpeg, const Sample *s, CFDictionaryRef *properties) {
    unsigned char app1[256];
    size_t length = makeApp1(s, app1);
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    CFDataAppendBytes(data, CFDataGetBytePtr(jpeg), 2);
    CFDataAppendBytes(data, app1, length);
    CFDataAppendBytes(data, CFDataGetBytePtr(jpeg) + 2, CFDataGetLength(jpeg) - 2);
    CGImageSourceRef source = CGImageSourceCreateWithData(data, NULL);
    if (source == NULL) return NULL;
    *properties = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    return *properties ? CFDictionaryGetValue(*properties, CFSTR("{GPS}")) : NULL;
}

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

    // The second probe's case 5 (lines 64-79): N 37/1 30/1 0/1, E 122/1 15/1 0/1, altitude 100/1 read back as the
    // doubles 37.5, 122.25 and 100 and the Ref strings, each a CFNumber float of 8 bytes.
    Sample probe = { "N", { 37, 30, 0 }, "E", { 122, 15, 0 }, 100 };
    CFDictionaryRef properties = NULL;
    CFDictionaryRef gps = gpsOf(plain, &probe, &properties);
    EXPECT(gps != NULL && CFGetTypeID(gps) == CFDictionaryGetTypeID(), "the {GPS} dictionary exists");
    EXPECT(isDoubleNear(at(gps, "Latitude"), 37.5), "Latitude is the double 37.5 (37 30 0)");
    EXPECT(isString(at(gps, "LatitudeRef"), "N"), "LatitudeRef is N");
    EXPECT(isDoubleNear(at(gps, "Longitude"), 122.25), "Longitude is the double 122.25 (122 15 0)");
    EXPECT(isString(at(gps, "LongitudeRef"), "E"), "LongitudeRef is E");
    EXPECT(isDoubleNear(at(gps, "Altitude"), 100), "Altitude is the double 100");
    EXPECT(at(gps, "GPSLatitude") == NULL && at(gps, "GPSAltitude") == NULL && at(gps, "GPSAltitudeRef") == NULL, "the raw tag names are not used");
    // GUESS, not in the probe for raw tags: the byte of tag 5 is given as a 4-byte integer, as for a written AltitudeRef (line 14).
    CFTypeRef altitudeRef = at(gps, "AltitudeRef");
    int altitudeRefValue = -1;
    EXPECT(altitudeRef != NULL && CFGetTypeID(altitudeRef) == CFNumberGetTypeID() && !CFNumberIsFloatType(altitudeRef) &&
           CFNumberGetByteSize(altitudeRef) == 4 && CFNumberGetValue(altitudeRef, kCFNumberIntType, &altitudeRefValue) && altitudeRefValue == 0,
           "AltitudeRef is the integer 0 (GUESS)");
    CFRelease(properties);

    // Minutes and seconds count, and the Ref carries the sign (lines 37-52: 33.8 with Ref S stays 33.8): 33 48 18 S is
    // 33 + 48/60 + 18/3600 = 33.805, 122 15 36 W is 122 + 15/60 + 36/3600 = 122.26, both positive.
    Sample south = { "S", { 33, 48, 18 }, "W", { 122, 15, 36 }, 3 };
    gps = gpsOf(plain, &south, &properties);
    EXPECT(gps != NULL, "the second {GPS} dictionary exists");
    EXPECT(isDoubleNear(at(gps, "Latitude"), 33.805), "Latitude is 33.805, not negative");
    EXPECT(isString(at(gps, "LatitudeRef"), "S"), "LatitudeRef is S");
    EXPECT(isDoubleNear(at(gps, "Longitude"), 122.26), "Longitude is 122.26, not negative");
    EXPECT(isString(at(gps, "LongitudeRef"), "W"), "LongitudeRef is W");
    EXPECT(isDoubleNear(at(gps, "Altitude"), 3), "Altitude is 3");
    CFRelease(properties);

    // A tag the decoder cannot turn into a number is dropped, not given as infinity or a guess: a zero denominator (here in
    // the seconds, which drops the whole Latitude; Longitude and Altitude stay) and more than three rationals. Not a probe
    // result: the choice is ours (the Mac's behaviour for such a file was not probed).
    Sample zero = { "N", { 37, 30, 0 }, "E", { 122, 15, 0 }, 100, 0, 1 };
    gps = gpsOf(plain, &zero, &properties);
    EXPECT(gps != NULL, "the {GPS} dictionary of the zero denominator file exists");
    EXPECT(at(gps, "Latitude") == NULL, "a zero denominator drops Latitude");
    EXPECT(isDoubleNear(at(gps, "Longitude"), 122.25) && isDoubleNear(at(gps, "Altitude"), 100), "the other tags stay");
    CFRelease(properties);
    Sample four = { "N", { 37, 30, 0 }, "E", { 122, 15, 0 }, 100, 4, 0 };
    gps = gpsOf(plain, &four, &properties);
    EXPECT(gps != NULL, "the {GPS} dictionary of the four-rational file exists");
    EXPECT(at(gps, "Latitude") == NULL, "four rationals drop Latitude");
    EXPECT(isDoubleNear(at(gps, "Longitude"), 122.25) && isDoubleNear(at(gps, "Altitude"), 100), "the other tags stay with four latitude rationals");
    CFRelease(properties);
    printf("PASS: JPEG GPS dictionary keys and values\n");
    return 0;
}
