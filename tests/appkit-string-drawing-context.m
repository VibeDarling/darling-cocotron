// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// NSStringDrawingContext (NSStringDrawing.h): minimumScaleFactor and minimumTrackingAdjustment are settable
// limits, actualScaleFactor, actualTrackingAdjustment and totalBounds are read-only results. With no scaling
// applied the actual scale factor is 1.0 (the documented "no scaling" value of a scale factor).
int main(void) {
    @autoreleasepool {
        NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
        expect(context != nil, @"the context is instantiable");
        expect([context minimumScaleFactor] == 0.0, @"no minimum scale factor by default");
        expect([context minimumTrackingAdjustment] == 0.0, @"no minimum tracking adjustment by default");
        expect([context actualScaleFactor] == 1.0, @"an undrawn context reports no scaling");
        expect(NSEqualRects([context totalBounds], NSZeroRect), @"an undrawn context has empty total bounds");

        [context setMinimumScaleFactor:0.5];
        [context setMinimumTrackingAdjustment:-2.0];
        expect([context minimumScaleFactor] == 0.5, @"minimumScaleFactor is stored");
        expect([context minimumTrackingAdjustment] == -2.0, @"minimumTrackingAdjustment is stored");
        expect(![context respondsToSelector:@selector(setActualScaleFactor:)], @"actualScaleFactor is read-only");

        NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"x"];
        expect([text respondsToSelector:@selector(drawWithRect:options:context:)], @"drawing accepts the context");

        // Drawing into a bitmap reports the drawn bounds in the context.
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:200 pixelsHigh:100
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        NSGraphicsContext *graphics = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:graphics];
        NSAttributedString *sentence = [[NSAttributedString alloc] initWithString:@"Hello, drawing context"];
        [sentence drawWithRect:NSMakeRect(5, 6, 200, 100) options:0 context:context];
        [NSGraphicsContext restoreGraphicsState];
        NSRect total = [context totalBounds];
        expect(total.size.width > 0 && total.size.height > 0, @"drawing sets non-empty total bounds");
        expect(total.size.width <= 200 && total.size.height <= 100, @"the total bounds fit the drawing rect");
        expect([context actualScaleFactor] == 1.0, @"nothing was scaled");
        [context release];
        [text release];
        NSLog(@"PASS: NSStringDrawingContext");
    }
    return 0;
}
