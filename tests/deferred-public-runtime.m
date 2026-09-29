// Public-API smoke gate for the rebuilt frameworks, not extracted method bodies.
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#import <objc/runtime.h>

typedef id (*BitmapInitializer)(id,SEL,unsigned char **,int,int,int,int,BOOL,BOOL,NSString *,NSBitmapFormat,int,int);
static BitmapInitializer originalBitmapInitializer;
static unsigned bitmapAttempts;
static id failFirstBitmap(id self, SEL sel, unsigned char **planes, int width,
        int height, int bits, int samples, BOOL alpha, BOOL planar,
        NSString *space, NSBitmapFormat format, int row, int pixel) {
    if (++bitmapAttempts == 1) { [self release]; return nil; }
    return originalBitmapInitializer(self,sel,planes,width,height,bits,samples,
        alpha,planar,space,format,row,pixel);
}

static void checkBitmapFailureRetry(CGContextRef port) {
    NSGraphicsContext *context=[NSGraphicsContext currentContext];
    size_t bytes=CGBitmapContextGetBytesPerRow(port)*CGBitmapContextGetHeight(port);
    void *data=CGBitmapContextGetData(port);
    void *before=malloc(bytes);
    assert(before && data);
    memcpy(before,data,bytes);
    __block unsigned calls=0;
    NSImage *image=[NSImage imageWithSize:NSMakeSize(20,20) flipped:NO
        drawingHandler:^BOOL(NSRect rect) {
            ++calls; [[NSColor redColor] setFill]; NSRectFill(rect); return YES;
        }];
    SEL selector=@selector(initWithBitmapDataPlanes:pixelsWide:pixelsHigh:bitsPerSample:samplesPerPixel:hasAlpha:isPlanar:colorSpaceName:bitmapFormat:bytesPerRow:bitsPerPixel:);
    Method method=class_getInstanceMethod([NSBitmapImageRep class],selector);
    assert(method);
    bitmapAttempts=0;
    originalBitmapInitializer=(BitmapInitializer)method_setImplementation(method,(IMP)failFirstBitmap);
    @try {
        [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
        assert(bitmapAttempts==1 && calls==0);
        assert([NSGraphicsContext currentContext]==context && memcmp(before,data,bytes)==0);
        [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
        assert(bitmapAttempts==2 && calls==1);
        [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
        assert(bitmapAttempts==2 && calls==1);
        assert([NSGraphicsContext currentContext]==context);
    } @finally {
        method_setImplementation(method,(IMP)originalBitmapInitializer);
        free(before);
    }
    puts("PASS: nil bitmap leaves destination unchanged, retries, and then reuses cache");
}

static void compareAlphaCompositing(CGContextRef port) {
    const CGFloat colors[][4] = {
        {0.125, 0.375, 0.75, 1}, {0.125, 0.375, 0.75, 0.5},
        {1, 0.25, 0, 0.25}, {0, 1, 0.5, 0}
    };
    size_t bytes = CGBitmapContextGetBytesPerRow(port) * CGBitmapContextGetHeight(port);
    unsigned char *data = CGBitmapContextGetData(port);
    unsigned char *rendered = malloc(bytes);
    assert(rendered != NULL && data != NULL);
    for (unsigned c = 0; c < 4; ++c) for (unsigned over = 0; over < 2; ++over) {
        CGFloat red=colors[c][0], green=colors[c][1], blue=colors[c][2], alpha=colors[c][3];
        __block unsigned calls = 0;
        NSImage *image = [NSImage imageWithSize:NSMakeSize(20,20) flipped:NO
            drawingHandler:^BOOL(NSRect rect) {
                ++calls;
                CGContextRef p = [[NSGraphicsContext currentContext] graphicsPort];
                CGContextSetRGBFillColor(p,red,green,blue,alpha);
                CGContextFillRect(p,rect);
                return YES;
            }];
        for (unsigned direct=0; direct<2; ++direct) {
            // Start both paths from identical bytes. Rotated background edges
            // can have fractional coverage and must not accumulate prior draws.
            memset(data,0,bytes);
            CGContextSaveGState(port);
            CGContextSetBlendMode(port,kCGBlendModeCopy);
            CGContextSetRGBFillColor(port,0.1,0.2,0.3,1);
            CGContextFillRect(port,CGRectMake(0,0,40,40));
            if (direct) {
                CGContextSetBlendMode(port,over ? kCGBlendModeNormal : kCGBlendModeCopy);
                CGContextSetRGBFillColor(port,red,green,blue,alpha);
                CGContextFillRect(port,CGRectMake(0,0,20,20));
            } else {
                [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect
                    operation:over ? NSCompositeSourceOver : NSCompositeCopy fraction:1];
            }
            CGContextRestoreGState(port);
            if (!direct) memcpy(rendered,data,bytes);
        }
        unsigned maxError = 0;
        for (size_t i=0; i<bytes; ++i) {
            unsigned error = abs((int)rendered[i]-(int)data[i]);
            if (error > maxError) maxError = error;
        }
        printf("Deferred color=%u sourceOver=%u max byte error=%u\n",c,over,maxError);
        // One byte level accommodates the additional 8-bit intermediate rounding.
        assert(calls == 1 && maxError <= 1);
    }
    free(rendered);
}

static void comparePatternedCrop(CGContextRef port) {
    size_t bytes=CGBitmapContextGetBytesPerRow(port)*CGBitmapContextGetHeight(port);
    unsigned char *data=CGBitmapContextGetData(port), *rendered=malloc(bytes);
    assert(data && rendered);
    __block unsigned calls=0;
    NSImage *image=[NSImage imageWithSize:NSMakeSize(20,20) flipped:NO
        drawingHandler:^BOOL(NSRect rect) {
            ++calls;
            CGContextRef p=[[NSGraphicsContext currentContext] graphicsPort];
            for (unsigned y=0;y<2;++y) for (unsigned x=0;x<2;++x) {
                CGContextSetRGBFillColor(p,x,y,1-x,1);
                CGContextFillRect(p,CGRectMake(x*10,y*10,10,10));
            }
            return YES;
        }];
    for (unsigned pass=0;pass<3;++pass) {
        memset(data,0,bytes);
        CGContextSaveGState(port);
        if (pass<2) {
            // Crop through all four quadrants and scale the central 10x10
            // region to 20x20. A solid fill cannot expose crop/orientation bugs.
            [image drawInRect:NSMakeRect(0,0,20,20)
                fromRect:NSMakeRect(5,5,10,10) operation:NSCompositeCopy fraction:1];
            assert(calls==1);
            if (pass==0) memcpy(rendered,data,bytes);
            else assert(memcmp(rendered,data,bytes)==0);
        } else {
            CGContextSetBlendMode(port,kCGBlendModeCopy);
            for (unsigned y=0;y<2;++y) for (unsigned x=0;x<2;++x) {
                CGContextSetRGBFillColor(port,x,y,1-x,1);
                CGContextFillRect(port,CGRectMake(x*10,y*10,10,10));
            }
        }
        CGContextRestoreGState(port);
    }
    unsigned maxError=0;
    size_t differingBytes=0, worst=0;
    for (size_t i=0;i<bytes;++i) {
        unsigned error=abs((int)rendered[i]-(int)data[i]);
        if (error) ++differingBytes;
        if (error>maxError) { maxError=error; worst=i; }
    }
    printf("Patterned crop max byte error=%u callback count=%u\n",maxError,calls);
    if (maxError) printf("Differing bytes=%zu worst offset=%zu cached=%u direct=%u rowBytes=%zu\n",
        differingBytes,worst,rendered[worst],data[worst],CGBitmapContextGetBytesPerRow(port));
    assert(maxError<=1);
    free(rendered);
}

static void checkFailedHandlerRetry(CGContextRef port) {
    NSGraphicsContext *context=[NSGraphicsContext currentContext];
    size_t bytes=CGBitmapContextGetBytesPerRow(port)*CGBitmapContextGetHeight(port);
    void *data=CGBitmapContextGetData(port), *before=malloc(bytes);
    assert(before && data);
    memcpy(before,data,bytes);
    __block unsigned calls=0, mode=0;
    NSImage *image=[NSImage imageWithSize:NSMakeSize(20,20) flipped:NO
        drawingHandler:^BOOL(NSRect rect) {
            ++calls; [[NSColor blueColor] setFill]; NSRectFill(rect);
            if (mode==1) [NSException raise:@"DeferredTestFailure" format:@"injected handler failure"];
            return mode==2;
        }];
    [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
    assert(calls==1 && [NSGraphicsContext currentContext]==context);
    assert(memcmp(before,data,bytes)==0);
    mode=1;
    BOOL caught=NO;
    @try {
        [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
    } @catch (NSException *error) {
        assert([[error name] isEqualToString:@"DeferredTestFailure"]); caught=YES;
    }
    assert(caught && calls==2 && [NSGraphicsContext currentContext]==context);
    assert(memcmp(before,data,bytes)==0);
    mode=2;
    [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
    assert(calls==3);
    [image drawInRect:NSMakeRect(0,0,20,20) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
    assert(calls==3 && [NSGraphicsContext currentContext]==context);
    free(before);
    puts("PASS: failed and throwing public handlers preserve destination/context and retry");
}

static void checkTransformDensityAndReuse(CGContextRef port) {
    CGAffineTransform transforms[]={
        CGAffineTransformMake(1.25,0,0,0.75,3,5),
        CGAffineTransformMake(1,0.25,0.375,1,3,5),
        CGAffineTransformMake(cos(0.37),sin(0.37),-sin(0.37),cos(0.37),12,5)
    };
    const unsigned order[]={0,1,2,0};
    __block unsigned calls=0;
    __block size_t expectedWidth=0,expectedHeight=0;
    NSImage *image=[NSImage imageWithSize:NSMakeSize(8,10) flipped:NO
        drawingHandler:^BOOL(NSRect rect) {
            ++calls;
            CGContextRef p=[[NSGraphicsContext currentContext] graphicsPort];
            CGAffineTransform t=CGContextGetUserSpaceToDeviceSpaceTransform(p);
            assert(CGBitmapContextGetWidth(p)==expectedWidth);
            assert(CGBitmapContextGetHeight(p)==expectedHeight);
            assert(fabs(hypot(t.a,t.b)-expectedWidth/8.0)<0.000001);
            assert(fabs(hypot(t.c,t.d)-expectedHeight/10.0)<0.000001);
            [[NSColor redColor] setFill]; NSRectFill(rect); return YES;
        }];
    size_t bytes=CGBitmapContextGetBytesPerRow(port)*CGBitmapContextGetHeight(port);
    unsigned char *data=CGBitmapContextGetData(port);
    assert(data && bytes);
    for (unsigned i=0;i<4;++i) {
        memset(data,0,bytes);
        CGContextSaveGState(port);
        CGContextConcatCTM(port,transforms[order[i]]);
        CGAffineTransform t=CGContextGetUserSpaceToDeviceSpaceTransform(port);
        expectedWidth=ceil(9.5*hypot(t.a,t.b));
        expectedHeight=ceil(7.25*hypot(t.c,t.d));
        [image drawInRect:NSMakeRect(0,0,9.5,7.25) fromRect:NSZeroRect
            operation:NSCompositeCopy fraction:1];
        assert(calls==(i<3 ? i+1 : 3));
        CGContextRestoreGState(port);
        BOOL painted=NO;
        for (size_t b=0;b<bytes;++b) if (data[b]) { painted=YES; break; }
        assert(painted);
        printf("Transform=%u raster=%zux%zu callback count=%u\n",
            order[i],expectedWidth,expectedHeight,calls);
    }
    puts("PASS: nonuniform/sheared/rotated device density and transform-key reuse");
}

int main(void) {
    setbuf(stdout, NULL);
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 40, 40)
        styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    [window setReleasedWhenClosed:NO];
    NSView *view = [window contentView];
    [view lockFocus];
    CGContextRef port = [[NSGraphicsContext currentContext] graphicsPort];
    double expected = getenv("TEST_EXPECT_WINDOW_SCALE") ?
        strtod(getenv("TEST_EXPECT_WINDOW_SCALE"), NULL) : 1;
    double actual = CGBitmapContextGetWidth(port) / 40.0;
    printf("Public window backing: expected=%g actual=%g\n", expected, actual);
    assert(fabs(actual - expected) < 0.000001);
    CGContextRef bitmap = NULL;
    if (getenv("TEST_BITMAP_DESTINATION")) {
        CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
        bitmap = CGBitmapContextCreate(NULL, 40, 40, 8, 160, color,
            kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(color);
        assert(bitmap != NULL);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:
            [NSGraphicsContext graphicsContextWithGraphicsPort:bitmap flipped:NO]];
        port = bitmap;
        expected = 1;
    }
    CGContextClearRect(port, CGRectMake(0, 0, 40, 40));
    checkBitmapFailureRetry(port);
    checkFailedHandlerRetry(port);
    CGContextClearRect(port, CGRectMake(0, 0, 40, 40));
    __block unsigned calls = 0;
    NSImage *image = [NSImage imageWithSize:NSMakeSize(20, 20) flipped:NO
        drawingHandler:^BOOL(NSRect rect) {
            ++calls;
            CGContextRef callbackPort = [[NSGraphicsContext currentContext] graphicsPort];
            CGAffineTransform transform = CGContextGetUserSpaceToDeviceSpaceTransform(callbackPort);
            double density = hypot(transform.a, transform.b);
            printf("Deferred callback density: expected=%g actual=%g\n", expected, density);
            assert(fabs(density - expected) < 0.000001);
            [[NSColor redColor] setFill];
            NSRectFill(rect);
            return YES;
        }];
    assert(image != nil && calls == 0);
    [image drawInRect:NSMakeRect(0, 0, 20, 20) fromRect:NSZeroRect
        operation:NSCompositeCopy fraction:1];
    assert(calls == 1);
    [image drawInRect:NSMakeRect(0, 0, 20, 20) fromRect:NSZeroRect
        operation:NSCompositeCopy fraction:1];
    assert(calls == 1);
    [image recache];
    [image drawInRect:NSMakeRect(0, 0, 20, 20) fromRect:NSZeroRect
        operation:NSCompositeCopy fraction:1];
    assert(calls == 2);
    size_t bytes = CGBitmapContextGetBytesPerRow(port) * CGBitmapContextGetHeight(port);
    void *data = CGBitmapContextGetData(port);
    assert(bytes > 0 && data != NULL);
    void *rendered = malloc(bytes);
    assert(rendered != NULL);
    memcpy(rendered, data, bytes);
    CGContextClearRect(port, CGRectMake(0, 0, 40, 40));
    [[NSColor redColor] setFill];
    NSRectFill(NSMakeRect(0, 0, 20, 20));
    assert(memcmp(rendered, data, bytes) == 0);
    free(rendered);
    compareAlphaCompositing(port);
    comparePatternedCrop(port);
    CGContextSaveGState(port);
    CGContextTranslateCTM(port,40,0);
    CGContextScaleCTM(port,-1,1);
    puts("Checking reflected destination");
    compareAlphaCompositing(port);
    comparePatternedCrop(port);
    CGContextRestoreGState(port);
    CGContextSaveGState(port);
    CGContextConcatCTM(port,CGAffineTransformMake(0,1,-1,0,40,0));
    puts("Checking exact-matrix quarter-turn patterned destination");
    comparePatternedCrop(port);
    CGContextRestoreGState(port);
    CGContextSaveGState(port);
    CGContextTranslateCTM(port,40,0);
    CGContextRotateCTM(port,M_PI_2);
    puts("Checking quarter-turn destination");
    compareAlphaCompositing(port);
    comparePatternedCrop(port);
    CGContextRestoreGState(port);
    checkTransformDensityAndReuse(port);
    if (bitmap) {
        [NSGraphicsContext restoreGraphicsState];
        CGContextRelease(bitmap);
    }
    [view unlockFocus];
    [window close];
    [window release];
    [pool drain];
    puts("PASS: rebuilt public NSImage deferred drawing and observed window scale");
    return 0;
}
