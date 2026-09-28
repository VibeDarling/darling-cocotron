#!/usr/bin/env ruby
# Exercise the candidate resize method against staged Onyx2D dependencies.
# Usage: ruby build-surface-resize-probe.rb BUILD_HELPER.rb [ONYX2D_LIBRARY]
# BUILD_HELPER accepts SOURCE.m and an extra library path. The default library
# location matches the darling-aarch64-getting-started stage18 workspace.
require 'tmpdir'
root=File.expand_path('..',__dir__)
method=File.read("#{root}/Onyx2D/O2Surface.m")[/- \(void\) setWidth:.*?(?=\nvoid \*O2SurfaceGetPixelBytes)/m]
abort 'resize method missing' unless method
source=<<~OBJC
  #import <Foundation/Foundation.h>
  #import <Onyx2D/O2Surface.h>
  #import <Onyx2D/O2DataProvider.h>
  #import <Onyx2D/O2ColorSpace.h>
  #include <stdint.h>
  #include <assert.h>
  #include <stdio.h>
  @implementation O2Surface (CandidateResize)
  #{method}
  @end
  int main(void) {
      setbuf(stdout,NULL);
      NSAutoreleasePool *pool=[NSAutoreleasePool new];
      O2ColorSpaceRef space=O2ColorSpaceCreateDeviceRGB();
      O2Surface *surface=[[O2Surface alloc] initWithBytes:NULL width:2 height:2
          bitsPerComponent:8 bytesPerRow:0 colorSpace:space
          bitmapInfo:kO2ImageAlphaPremultipliedFirst|kO2BitmapByteOrder32Little];
      O2ColorSpaceRelease(space);
      assert(surface!=nil);
      unsigned char *bytes=[surface pixelBytes];
      bytes[0]=73;
      size_t widths[]={SIZE_MAX/32+1,2};
      size_t heights[]={2,SIZE_MAX/8+1};
      for (unsigned mode=0;mode<2;++mode) for (unsigned n=0;n<2;++n) {
          BOOL rejected=NO;
          @try { [surface setWidth:widths[n] height:heights[n] reallocateOnlyIfRequired:mode]; }
          @catch (NSException *exception) {
              assert([[exception name] isEqual:NSInvalidArgumentException]);
              rejected=YES;
          }
          assert(rejected);
          assert(O2SurfaceGetWidth(surface)==2 && O2SurfaceGetHeight(surface)==2);
          assert([surface pixelBytes]==bytes && bytes[0]==73);
      }
      [surface setWidth:1 height:2 reallocateOnlyIfRequired:YES];
      assert(O2SurfaceGetWidth(surface)==1 && [surface pixelBytes]==bytes);
      assert(((unsigned char *)[surface pixelBytes])[0]==73);
      [surface setWidth:4 height:4 reallocateOnlyIfRequired:NO];
      assert(O2SurfaceGetWidth(surface)==4 && O2SurfaceGetHeight(surface)==4);
      assert([surface pixelBytes]!=NULL);
      [surface release];
      unsigned char external[16]={91};
      space=O2ColorSpaceCreateDeviceRGB();
      surface=[[O2Surface alloc] initWithBytes:external width:2 height:2
          bitsPerComponent:8 bytesPerRow:8 colorSpace:space
          bitmapInfo:kO2ImageAlphaPremultipliedFirst|kO2BitmapByteOrder32Little];
      O2ColorSpaceRelease(space);
      assert(surface!=nil);
      for (unsigned mode=0;mode<2;++mode) {
          [surface setWidth:SIZE_MAX height:SIZE_MAX reallocateOnlyIfRequired:mode];
          assert(O2SurfaceGetWidth(surface)==2 && O2SurfaceGetHeight(surface)==2);
          assert([surface pixelBytes]==external && external[0]==91);
      }
      [surface release];
      assert(external[0]==91);
      puts("PASS: both resize modes reject overflow; external buffers remain untouched");
      [pool release];
      puts("PASS: resize overflow rejected before mutation; valid shrink and grow succeed");
      return 0;
  }
OBJC
Dir.mktmpdir('surface-resize-source-') do |dir|
  file="#{dir}/probe.m"
  File.write(file,source)
  library=ARGV[1] || File.expand_path('../../build-arm64-stage18/src/external/cocotron/Onyx2D/Onyx2D',root)
  abort 'probe build failed' unless system({'COCOTRON_DIR'=>root},'ruby',ARGV.fetch(0),file,library)
end
