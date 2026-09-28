# Build the exact candidate factory in a subclass of staged NSImage, alongside
# the renamed candidate NSCustomImageRep. Does not substitute staged factory code.
# Usage: ruby build-deferred-factory-probe.rb /path/to/build-staged-appkit-probe.rb
require 'tmpdir'
root=File.expand_path('..', __dir__)
source=File.read("#{root}/AppKit/NSImage.m")
factory=source[/\+ \(instancetype\) imageWithSize:.*?\n\}/m]
abort 'factory method missing' unless factory
cache=source[/ +if \(cachedRep == nil\) \{.*?(?=\n\n +\/\/ A full bitmap)/m]
abort 'temporary cache block missing' unless cache
test=File.read("#{__dir__}/deferred-handler-ownership.m")
test.sub!('../AppKit/NSCustomImageRep.m', "#{root}/AppKit/NSCustomImageRep.m")
insertion=<<~OBJC
  #import <AppKit/NSImage.h>
  #import <AppKit/NSCachedImageRep.h>
  #import "#{root}/AppKit/NSGraphicsContextFunctions.h"
  #import <AppKit/NSApplication.h>
  @interface DeferredFactoryProbe : NSImage @end
  @implementation DeferredFactoryProbe
  #{factory}
  - (void)probeCache:(NSImageRep *)any {
      NSImageRep *cachedRep=nil;
      NSRect source=NSZeroRect;
      BOOL canCache=NO;
      CGContextRef context;
      #{cache}
  }
  @end
  static void testFactory(void) {
      __block unsigned calls=0;
      NSImage *image=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,30)
          flipped:YES drawingHandler:^BOOL(NSRect rect) {
              ++calls; return NO;
          }];
      assert([image isKindOfClass:[DeferredFactoryProbe class]]);
      assert(calls==0 && NSEqualSizes([image size],NSMakeSize(20,30)));
      assert([[image representations] count]==1);
      DeferredProbeImageRep *rep=[[image representations] objectAtIndex:0];
      assert([rep isKindOfClass:[DeferredProbeImageRep class]]);
      assert(![rep drawingHandler](NSMakeRect(0,0,20,30)) && calls==1);
      puts("PASS: candidate image factory defers drawing and installs candidate representation");
      if (getenv("TEST_DESTINATION_SCALE")) {
          [NSApplication sharedApplication];
          unsigned char pixels[64*64*4]={0};
          CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
          CGContextRef port=CGBitmapContextCreate(pixels,64,64,8,64*4,color,kCGImageAlphaPremultipliedLast);
          CGColorSpaceRelease(color);
          assert(port!=NULL);
          CGContextScaleCTM(port,2,2);
          NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithGraphicsPort:port flipped:NO];
          [NSGraphicsContext setCurrentContext:context];
          __block CGFloat observed=0;
          DeferredFactoryProbe *scaled=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,30)
              flipped:NO drawingHandler:^BOOL(NSRect rect) {
                  observed=CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]).a;
                  return YES;
              }];
          [scaled probeCache:[[scaled representations] objectAtIndex:0]];
          printf("Destination scale=2, handler cache scale=%g\\n",(double)observed);
          assert(observed==2);
          [NSGraphicsContext setCurrentContext:nil];
          CGContextRelease(port);
          puts("PASS: temporary cache preserves destination scale");
      }
  }
OBJC
test.sub!('// FACTORY_INSERTION_POINT', insertion)
Dir.mktmpdir('deferred-factory-source-') do |dir|
  path="#{dir}/probe.m"
  File.write(path,"#define TEST_DEFERRED_FACTORY 1\n"+test)
  abort 'build failed' unless system({'COCOTRON_DIR'=>root},'ruby',ARGV.fetch(0),path)
end
