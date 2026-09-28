// Compile the candidate implementation under a distinct class name so a staged
// AppKit cannot silently supply its own NSCustomImageRep implementation.
#define NSCustomImageRep DeferredProbeImageRep
#import "../AppKit/NSCustomImageRep.m"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <CoreGraphics/CoreGraphics.h>
#include <assert.h>
#include <stdio.h>

static unsigned destroyed, invoked;
@interface HandlerToken : NSObject
@end
@implementation HandlerToken
- (void)dealloc { ++destroyed; [super dealloc]; }
@end

static DeferredProbeImageRep *makeRepresentation(void) {
    HandlerToken *token = [HandlerToken new];
    int captured = 73;
    DeferredProbeImageRep *rep = [[DeferredProbeImageRep alloc]
        initWithSize:NSMakeSize(20, 30) flipped:NO drawingHandler:^BOOL(NSRect rect) {
            assert([token class] == [HandlerToken class]);
            assert(captured == 73);
            assert(NSEqualRects(rect, NSMakeRect(0, 0, 20, 30)));
            ++invoked;
            return NO;
        }];
    [token release];
    return rep;
}

static BOOL sameTransform(CGAffineTransform a, CGAffineTransform b) {
    return a.a==b.a && a.b==b.b && a.c==b.c && a.d==b.d && a.tx==b.tx && a.ty==b.ty;
}

static void testDrawing(void) {
    for (unsigned destinationFlipped=0; destinationFlipped<2; ++destinationFlipped) {
        for (unsigned handlerFlipped=0; handlerFlipped<2; ++handlerFlipped) {
            unsigned char pixels[32*32*4] = {0};
            CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
            CGContextRef port = CGBitmapContextCreate(pixels,32,32,8,32*4,color,
                kCGImageAlphaPremultipliedLast);
            assert(port != NULL);
            CGColorSpaceRelease(color);
            if (destinationFlipped) {
                CGContextTranslateCTM(port,0,30);
                CGContextScaleCTM(port,1,-1);
            }
            NSGraphicsContext *context = [NSGraphicsContext
                graphicsContextWithGraphicsPort:port flipped:destinationFlipped];
            [NSGraphicsContext setCurrentContext:context];
            CGAffineTransform before = CGContextGetCTM(port);
            CGAffineTransform expected = before;
            if (destinationFlipped != handlerFlipped) {
                expected = CGAffineTransformTranslate(expected,0,30);
                expected = CGAffineTransformScale(expected,1,-1);
            }
            __block BOOL shouldThrow = NO, result = NO;
            __block unsigned calls = 0;
            DeferredProbeImageRep *rep = [[DeferredProbeImageRep alloc]
                initWithSize:NSMakeSize(20,30) flipped:handlerFlipped
                drawingHandler:^BOOL(NSRect rect) {
                    ++calls;
                    assert([NSGraphicsContext currentContext] == context);
                    assert([context isFlipped] == handlerFlipped);
                    assert(NSEqualRects(rect,NSMakeRect(0,0,20,30)));
                    assert(sameTransform(CGContextGetCTM(port),expected));
                    CGContextSetRGBFillColor(port,1,0,0,1);
                    CGContextFillRect(port,CGRectMake(0,0,20,30));
                    CGContextTranslateCTM(port,7,9);
                    if (shouldThrow)
                        [NSException raise:@"DrawingProbe" format:@"expected"];
                    return result;
                }];
            assert(calls == 0);
            for (unsigned mode=0;mode<3;++mode) {
                result = mode == 1;
                shouldThrow = mode == 2;
                BOOL caught = NO;
                @try { assert([rep draw] == result); }
                @catch (NSException *exception) {
                    caught = [[exception name] isEqual:@"DrawingProbe"];
                }
                assert(caught == shouldThrow && calls == mode+1);
                assert([NSGraphicsContext currentContext] == context);
                assert([context isFlipped] == destinationFlipped);
                assert([[context focusStack] count] == 0);
                assert(sameTransform(CGContextGetCTM(port),before));
            }
            unsigned changed = 0;
            for (unsigned i=0;i<sizeof(pixels);++i) changed += pixels[i] != 0;
            assert(changed > 0);
            [rep release];
            [NSGraphicsContext setCurrentContext:nil];
            CGContextRelease(port);
        }
    }
    puts("PASS: four flip combinations, bitmap writes, NO/YES results and exception state restoration");
}

// FACTORY_INSERTION_POINT

int main(void) {
    setbuf(stdout, NULL);
    puts("BEGIN: candidate deferred handler ownership");
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    DeferredProbeImageRep *rep = makeRepresentation();
    assert(invoked == 0 && destroyed == 0);
    DeferredProbeImageRep *copy = [rep copy];
    [rep release];
    assert(invoked == 0 && destroyed == 0);
    assert(![copy drawingHandler](NSMakeRect(0, 0, 20, 30)));
    assert(invoked == 1 && destroyed == 0);
    [copy release];
    testDrawing();
#ifdef TEST_DEFERRED_FACTORY
    testFactory();
#endif
    [pool release];
    assert(destroyed == 1);
    puts("PASS: deferred invocation, escaped capture and independent representation copy lifetime");
    return 0;
}
