#import <Onyx2D/O2ImageDecoder_JPEG_stb.h>

/* JPEG decoding by stb_image v2.30 (public domain, Sean Barrett:
 * https://github.com/nothings/stb), stb_image.h next to this file. Unlike the
 * 1.14 decoder Onyx2D carried before, it reads progressive JPEGs. */
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
// No failure strings: they live in a thread-local variable.
#define STBI_NO_FAILURE_STRINGS
#define STBI_NO_THREAD_LOCALS
#define STB_IMAGE_STATIC
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

@implementation O2ImageDecoder_JPEG_stb

- initWithDataProvider: (O2DataProviderRef) dataProvider {

    _compressionType = O2ImageCompressionJPEG;
    _dataProvider = [dataProvider retain];

    CFDataRef encodedData = O2DataProviderCopyData(dataProvider);
    CFIndex encodedLength = CFDataGetLength(encodedData);
    const uint8_t *encodedBytes = CFDataGetBytePtr(encodedData);

    int comp;
    uint8_t *bitmap = NULL;
    int width, height;

    if (encodedLength > 0 && encodedLength <= INT_MAX)
        bitmap = stbi_load_from_memory(encodedBytes, (int) encodedLength,
                                       &width, &height, &comp, STBI_rgb_alpha);

    CFRelease(encodedData);

    if (bitmap == NULL) {
        [self dealloc];
        return nil;
    }

    _width = width;
    _height = height;
    _bitsPerComponent = 8;
    _bitsPerPixel = 32;
    _bytesPerRow = (_bitsPerPixel / (sizeof(char) * 8)) * _width;
    _colorSpace = O2ColorSpaceCreateDeviceRGB();
    _bitmapInfo = kO2BitmapByteOrder32Big | kO2ImageAlphaPremultipliedLast;

    _pixelData = (CFDataRef)
            [[NSData alloc] initWithBytesNoCopy: bitmap
                                         length: _bytesPerRow * _height
                                   freeWhenDone: YES];

    return self;
}

- (void) dealloc {
    [_dataProvider release];
    [_colorSpace release];
    // Unset when decoding failed.
    if (_pixelData != NULL)
        CFRelease(_pixelData);
    [super dealloc];
}

- (CFDataRef) createPixelData {
    return CFRetain(_pixelData);
}

@end
