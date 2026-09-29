// The builder inserts the unmodified initializer/dealloc from the source tree.
#import <AppKit/NSBitmapImageRep.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <assert.h>
#include <stdio.h>
static unsigned attempt, failAt, allocated, freed;
static void *tracked[16];
static void *faultCalloc(NSZone *zone, NSUInteger count, NSUInteger bytes) {
    if (++attempt == failAt) return NULL;
    void *p=NSZoneCalloc(zone,count,bytes);
    assert(p != NULL && allocated < 16);
    tracked[allocated++]=p;
    return p;
}
static void trackedFree(NSZone *zone, void *p) {
    BOOL found=NO;
    for (unsigned i=0;i<allocated;++i) if (tracked[i]==p) {
        found=YES; tracked[i]=NULL; ++freed; break;
    }
    assert(found); // Never free caller-owned storage or a pointer twice.
    NSZoneFree(zone,p);
}
#define NSZoneCalloc faultCalloc
#define NSZoneFree trackedFree
@implementation NSBitmapImageRep (AllocationFailureProbe)
// ACTUAL_METHODS
@end
#undef NSZoneCalloc
#undef NSZoneFree

static void run(unsigned failure, BOOL external) {
    attempt=allocated=freed=0; failAt=failure;
    unsigned char a[4]={11}, b[4]={22}, c[4]={33};
    unsigned char *planes[]={a,b,c};
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:external ? planes : NULL
        pixelsWide:2 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:3
        hasAlpha:NO isPlanar:YES colorSpaceName:NSDeviceRGBColorSpace
        bitmapFormat:0 bytesPerRow:2 bitsPerPixel:8];
    if (failure) assert(rep==nil);
    else { assert(rep!=nil); [rep release]; }
    assert(allocated==freed);
    assert(a[0]==11 && b[0]==22 && c[0]==33);
    printf("PASS: failure=%u external=%d allocations=%u frees=%u\n",
        failure,external,allocated,freed);
}
int main(void) {
    setbuf(stdout,NULL);
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    for (unsigned i=1;i<=4;++i) run(i,NO);
    run(0,NO);
    run(1,YES);
    run(0,YES);
    [pool drain];
    puts("PASS: bitmap allocation failures clean up partial planes and preserve external storage");
    return 0;
}
