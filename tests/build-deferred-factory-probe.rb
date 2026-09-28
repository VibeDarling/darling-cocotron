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
  - (void)probeCache:(NSImageRep *)any source:(NSRect)source destination:(NSRect)rect {
      NSImageRep *cachedRep=nil;
      BOOL canCache=NO;
      CGContextRef context;
      #{cache}
      [cachedRep drawInRect:rect];
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
          CGFloat scales[]={1,1.5,2};
          for (unsigned si=0;si<3;++si) for (unsigned crop=0;crop<2;++crop) {
          CGFloat scale=scales[si];
          NSRect source=crop ? NSMakeRect(2,4,10,20) : NSZeroRect;
          NSRect destination=crop ? NSMakeRect(0,0,10,20) : NSMakeRect(0,0,20,30);
          unsigned char pixels[64*64*4]={0};
          CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
          CGContextRef port=CGBitmapContextCreate(pixels,64,64,8,64*4,color,kCGImageAlphaPremultipliedLast);
          CGColorSpaceRelease(color);
          assert(port!=NULL);
          CGContextScaleCTM(port,scale,scale);
          NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithGraphicsPort:port flipped:NO];
          [NSGraphicsContext setCurrentContext:context];
          __block CGFloat observed=0;
          DeferredFactoryProbe *scaled=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,30)
              flipped:NO drawingHandler:^BOOL(NSRect rect) {
                  observed=CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]).a;
                  CGAffineTransform transform=CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]);
                  if (!getenv("TEST_IMAGE_FLIPPED"))
                      assert(transform.tx==-source.origin.x*scale && transform.ty==-source.origin.y*scale);
                  CGContextSetRGBFillColor([[NSGraphicsContext currentContext] graphicsPort],1,0,0,1);
                  CGContextFillRect([[NSGraphicsContext currentContext] graphicsPort],CGRectMake(0,0,20,30));
                  return YES;
              }];
          [scaled setFlipped:getenv("TEST_IMAGE_FLIPPED") != NULL];
          [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
          printf("Destination scale=%g crop=%u, handler cache scale=%g\\n",(double)scale,crop,(double)observed);
          unsigned painted=0,minX=64,minY=64,maxX=0,maxY=0;
          for (unsigned y=0;y<64;++y) {
              for (unsigned x=0;x<64;++x) {
                  unsigned char *pixel=&pixels[(y*64+x)*4];
                  BOOL nonzero=pixel[0] || pixel[1] || pixel[2] || pixel[3];
                  if (nonzero) {
                      ++painted;
                      minX=MIN(minX,x); minY=MIN(minY,y);
                      maxX=MAX(maxX,x); maxY=MAX(maxY,y);
                  }
              }
          }
          printf("Composited pixels=%u bounds=(%u,%u)-(%u,%u)\\n",painted,minX,minY,maxX,maxY);
          unsigned width=destination.size.width*scale, height=destination.size.height*scale;
          assert(painted==width*height && maxX-minX+1==width && maxY-minY+1==height);
          assert(observed==scale);
          [NSGraphicsContext setCurrentContext:nil];
          CGContextRelease(port);
          }
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
