// Compile with the staged AppKit probe builder and explicit Onyx2D library.
// Rename the candidate class to avoid testing the installed implementation.
#import <Foundation/Foundation.h>
#define O2Surface ConstructorProbeSurface
#import "../Onyx2D/O2Surface.m"
#undef O2Surface
#include <stdint.h>
#include <assert.h>
#include <stdio.h>

int main(void) {
    setbuf(stdout,NULL);
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    O2ColorSpaceRef space=O2ColorSpaceCreateDeviceRGB();
    size_t widths[]={SIZE_MAX/32+1,2};
    size_t heights[]={2,SIZE_MAX/8+1};
    for (unsigned n=0;n<2;++n) {
        ConstructorProbeSurface *surface=[[ConstructorProbeSurface alloc]
            initWithBytes:NULL width:widths[n] height:heights[n]
            bitsPerComponent:8 bytesPerRow:0 colorSpace:space
            bitmapInfo:kO2ImageAlphaPremultipliedFirst|kO2BitmapByteOrder32Little];
        printf("Overflow case %u rejected=%d\n",n,surface==nil);
        assert(surface==nil);
    }
    unsigned char external[32]={47};
    size_t strides[]={0,4,8,16};
    for (unsigned owned=0;owned<2;++owned) for (unsigned n=0;n<4;++n) {
        ConstructorProbeSurface *surface=[[ConstructorProbeSurface alloc]
            initWithBytes:owned?NULL:external width:2 height:2
            bitsPerComponent:8 bytesPerRow:strides[n] colorSpace:space
            bitmapInfo:kO2ImageAlphaPremultipliedFirst|kO2BitmapByteOrder32Little];
        if (!owned && strides[n]<8) {
            assert(surface==nil);
        } else {
            assert(surface!=nil && [surface pixelBytes]!=NULL);
            assert(O2SurfaceGetWidth(surface)==2 && O2SurfaceGetHeight(surface)==2);
            if (!owned) assert([surface pixelBytes]==external);
            O2SurfaceLock(surface);
            O2SurfaceUnlock(surface);
            [surface release];
        }
        assert(external[0]==47);
    }
    ConstructorProbeSurface *externalOverflow=[[ConstructorProbeSurface alloc]
        initWithBytes:external width:2 height:SIZE_MAX/8+1
        bitsPerComponent:8 bytesPerRow:8 colorSpace:space
        bitmapInfo:kO2ImageAlphaPremultipliedFirst|kO2BitmapByteOrder32Little];
    assert(externalOverflow==nil && external[0]==47);
    O2ColorSpaceRelease(space);
    [pool release];
    puts("PASS: constructor rejects overflowing backing sizes");
    return 0;
}
