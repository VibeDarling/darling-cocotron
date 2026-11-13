// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Apps send this private method to a template image.
@interface NSImage (TintProbe)
- (NSImage *)_imageByApplyingTintColor:(NSColor *)color;
@end

// The pixel at column x, row 0, as the bitmap stores it.
static const unsigned char *pixelOf(NSImage *image, NSUInteger x) {
    NSBitmapImageRep *rep = [[image representations] firstObject];
    return rep == nil ? NULL : [rep bitmapData] + x * 4;
}

int main(void) {
    @autoreleasepool {
        // A 4x2 source: left half opaque red, right half transparent.
        NSBitmapImageRep *sourceRep = [[[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:4 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:4
                            hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                         bytesPerRow:0 bitsPerPixel:32] autorelease];
        NSImage *source = [[NSImage alloc] initWithSize:NSMakeSize(4, 2)];
        [source addRepresentation:sourceRep];
        [source lockFocusOnRepresentation:sourceRep];
        [[NSColor redColor] set];
        NSRectFill(NSMakeRect(0, 0, 2, 2));
        [source unlockFocus];

        expect([source respondsToSelector:@selector(_imageByApplyingTintColor:)],
               @"NSImage answers -_imageByApplyingTintColor:");
        NSImage *tinted = [source _imageByApplyingTintColor:[NSColor blueColor]];
        expect(tinted != nil && tinted != source, @"the tinted image is a new image");
        expect(NSEqualSizes([tinted size], NSMakeSize(4, 2)), @"the tinted image keeps the size");

        const unsigned char *before = pixelOf(source, 0);
        const unsigned char *drawn = pixelOf(tinted, 0);
        const unsigned char *empty = pixelOf(tinted, 3);
        expect(before != NULL && drawn != NULL && empty != NULL, @"both images hold bitmap pixels");
        // Bytes are red, green, blue, alpha.
        expect(before[0] == 0xff && before[2] == 0x00 && before[3] == 0xff, @"the source pixel is opaque red");
        expect(drawn[0] == 0x00 && drawn[1] == 0x00 && drawn[2] == 0xff, @"a drawn pixel takes the tint color");
        expect(drawn[3] == 0xff, @"a drawn pixel stays opaque");
        expect(empty[3] == 0x00, @"a transparent pixel stays transparent");
        expect(before[0] == 0xff && before[2] == 0x00, @"the source image is not changed");

        // A translucent tint scales the image's alpha: half-alpha blue over the opaque pixel is half-alpha blue,
        // not an opaque blend of the source and the tint.
        NSImage *half = [source _imageByApplyingTintColor:[[NSColor blueColor] colorWithAlphaComponent:0.5]];
        const unsigned char *halfDrawn = pixelOf(half, 0);
        const unsigned char *halfEmpty = pixelOf(half, 3);
        expect(halfDrawn != NULL && halfEmpty != NULL, @"the half-alpha image holds bitmap pixels");
        expect(halfDrawn[0] == 0x00 && halfDrawn[1] == 0x00, @"the half-alpha tint keeps no red or green from the source");
        expect(halfDrawn[3] >= 0x7e && halfDrawn[3] <= 0x82, @"the half-alpha tint gives half alpha, not an opaque pixel");
        expect(halfEmpty[3] == 0x00, @"a transparent pixel stays transparent under a translucent tint");

        // With no color there is nothing to tint with: the result is a copy of the same size.
        NSImage *copy = [source _imageByApplyingTintColor:nil];
        expect(copy != nil && copy != source && NSEqualSizes([copy size], NSMakeSize(4, 2)), @"a nil color gives a copy");
        expect(pixelOf(copy, 0) != NULL && pixelOf(copy, 0)[0] == 0xff && pixelOf(copy, 0)[2] == 0x00,
               @"the copy keeps the source pixels, it is not painted black");

        [source release];
        NSLog(@"PASS: -_imageByApplyingTintColor:");
    }
    return 0;
}
