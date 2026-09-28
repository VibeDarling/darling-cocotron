// Compile the candidate implementation under a distinct class name so a staged
// AppKit cannot silently supply its own NSCustomImageRep implementation.
#define NSCustomImageRep DeferredProbeImageRep
#import "../AppKit/NSCustomImageRep.m"
#import <Foundation/NSAutoreleasePool.h>
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
    [pool release];
    assert(destroyed == 1);
    puts("PASS: deferred invocation, escaped capture and independent representation copy lifetime");
    return 0;
}
