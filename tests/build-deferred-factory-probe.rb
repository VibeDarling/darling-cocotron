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
selection_start=source.index("- (NSImageRep *)\n        _bestUncachedFallbackCachedRepresentationForDevice:")
selection_end=source.index("\n- (NSImageRep *) bestRepresentationForDevice:",selection_start)
selection=source[selection_start...selection_end]
reuse=source[/ +if \(canCache\) \{\n +\/\/ If we're drawing.*?(?=\n\n +if \(cachedRep == nil\))/m]
abort 'cache selection code missing' unless reuse
cache_mode=source[/- \(void\) setCacheMode:.*?\n\}/m]
abort 'cache mode setter missing' unless cache_mode
# Redirect only the new ivar to subclass storage; preserve setter behavior.
cache_mode=cache_mode.gsub('_drawingHandlerRepCache','_probeDrawingCache')
rep_methods=File.read("#{root}/AppKit/NSImageRep.m")[/- \(BOOL\) drawAtPoint:.*?(?=\n- \(NSString \*\) description)/m]
abort 'representation wrappers missing' unless rep_methods
test=File.read("#{__dir__}/deferred-handler-ownership.m")
test.sub!('../AppKit/NSCustomImageRep.m', "#{root}/AppKit/NSCustomImageRep.m")
insertion=<<~OBJC
  #import <AppKit/NSImage.h>
  #import <AppKit/NSCachedImageRep.h>
  #import <AppKit/NSBitmapImageRep.h>
  #import "#{root}/AppKit/NSGraphicsContextFunctions.h"
  #import <AppKit/NSApplication.h>
  #import <AppKit/NSAppearance.h>
  #import "#{root}/AppKit/NSImageDrawingCache.m"
  #include <string.h>
  @implementation DeferredProbeImageRep (CandidateDrawingWrappers)
  #{rep_methods}
  @end
  // Staged NSImage does not have the candidate's new cache ivar. Supply storage
  // in this subclass; the extracted lookup/population uses the same accessor.
  @interface DeferredFactoryProbe : NSImage { NSImageDrawingCache *_probeDrawingCache; } @end
  @implementation DeferredFactoryProbe
  - (NSImageDrawingCache *)_drawingHandlerCache {
      if (_probeDrawingCache==nil) _probeDrawingCache=[NSImageDrawingCache new];
      return _probeDrawingCache;
  }
  - (void)dealloc { [_probeDrawingCache release]; [super dealloc]; }
  #{factory}
  #{cache_mode}
  #{selection}
  - (void)probeCache:(NSImageRep *)any source:(NSRect)source destination:(NSRect)rect {
      NSImageRep *cachedRep=nil;
      BOOL canCache=NO;
      if (getenv("TEST_CACHE_REUSE")) {
          any=[self _bestUncachedFallbackCachedRepresentationForDevice:nil size:rect.size];
          canCache=NSIsEmptyRect(source) && ![self isFlipped];
          #{reuse}
      }
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
          // Derive byte values through the same bitmap backend, avoiding an
          // assumption about host byte order for the default bitmap format.
          unsigned char reference[12]={0};
          CGColorSpaceRef referenceColor=CGColorSpaceCreateDeviceRGB();
          CGContextRef referencePort=CGBitmapContextCreate(reference,3,1,8,12,referenceColor,kCGImageAlphaPremultipliedLast);
          CGColorSpaceRelease(referenceColor);
          assert(referencePort!=NULL);
          CGContextSetRGBFillColor(referencePort,1,0,0,1);
          CGContextFillRect(referencePort,CGRectMake(0,0,1,1));
          CGContextSetRGBFillColor(referencePort,0,0,1,1);
          CGContextFillRect(referencePort,CGRectMake(1,0,1,1));
          CGContextSetRGBFillColor(referencePort,0,1,0,1);
          CGContextFillRect(referencePort,CGRectMake(2,0,1,1));
          assert(memcmp(reference,reference+4,4)!=0);
          CGContextRelease(referencePort);
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
          __block unsigned renderCalls=0;
          __block BOOL renderResult=YES, renderThrows=NO;
          __block BOOL invalidateDuringDraw=NO;
          NSAppearance *originalAppearance=[NSAppearance currentAppearance];
          __block DeferredFactoryProbe *scaled=nil;
          scaled=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,30)
              flipped:NO drawingHandler:^BOOL(NSRect rect) {
                  ++renderCalls;
                  if (invalidateDuringDraw) [scaled setCacheMode:NSImageCacheAlways];
                  observed=CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]).a;
                  CGAffineTransform transform=CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]);
                  if (!getenv("TEST_IMAGE_FLIPPED"))
                      assert(transform.tx==-source.origin.x*scale && transform.ty==-source.origin.y*scale);
                  CGContextSetRGBFillColor([[NSGraphicsContext currentContext] graphicsPort],1,0,0,1);
                  CGContextFillRect([[NSGraphicsContext currentContext] graphicsPort],CGRectMake(0,0,20,30));
                  // A low, blue band distinguishes orientation from mere extent.
                  BOOL original=[NSAppearance currentAppearance]==originalAppearance;
                  CGContextSetRGBFillColor([[NSGraphicsContext currentContext] graphicsPort],0,original?0:1,original?1:0,1);
                  CGContextFillRect([[NSGraphicsContext currentContext] graphicsPort],CGRectMake(0,0,20,8));
                  if (renderThrows) [NSException raise:@"CacheDrawingProbe" format:@"expected"];
                  return renderResult;
              }];
          [scaled setFlipped:getenv("TEST_IMAGE_FLIPPED") != NULL];
          [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
          if (getenv("TEST_CACHE_REUSE") && !crop && ![scaled isFlipped]) {
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              printf("Same-destination draw calls=%u, representations=%lu\\n",renderCalls,(unsigned long)[[scaled representations] count]);
              assert(renderCalls==1);
          }
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
          unsigned sampleX=(unsigned)(5*scale);
          unsigned lowRow=63-(unsigned)(2*scale);
          unsigned highRow=63-(unsigned)((destination.size.height-2)*scale);
          unsigned char *low=&pixels[(lowRow*64+sampleX)*4];
          unsigned char *high=&pixels[(highRow*64+sampleX)*4];
          printf("Pattern low bytes=%u,%u,%u,%u high=%u,%u,%u,%u\\n",
              low[0],low[1],low[2],low[3],high[0],high[1],high[2],high[3]);
          assert(memcmp(low,reference+4,4)==0);
          assert(memcmp(high,reference,4)==0);
          if (getenv("TEST_CACHE_REUSE") && !crop && ![scaled isFlipped]) {
              CGContextSaveGState(port);
              CGContextScaleCTM(port,2,2);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==2 && observed==scale*2);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==2);
              CGContextRestoreGState(port);
              memset(pixels,0,sizeof(pixels));
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==2 && [[scaled representations] count]==1);
              assert(memcmp(low,reference+4,4)==0 && memcmp(high,reference,4)==0);
              puts("PASS: changed scale renders once; restoring scale reuses earlier raster");
              [scaled setCacheMode:NSImageCacheNever];
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==4);
              [scaled setCacheMode:NSImageCacheAlways];
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==5);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==5 && [[scaled representations] count]==1);
              puts("PASS: cache-never bypasses reuse; mode transition discards old entries");
              [scaled setCacheMode:NSImageCacheAlways];
              renderResult=NO;
              memset(pixels,0,sizeof(pixels));
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==6 && [NSGraphicsContext currentContext]==context);
              for (unsigned i=0;i<sizeof(pixels);++i) assert(pixels[i]==0);
              renderThrows=YES;
              BOOL caught=NO;
              @try { [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination]; }
              @catch (NSException *e) { caught=[[e name] isEqual:@"CacheDrawingProbe"]; }
              assert(caught && renderCalls==7 && [NSGraphicsContext currentContext]==context);
              renderThrows=NO; renderResult=YES;
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==8);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==8 && [[scaled representations] count]==1);
              assert(memcmp(low,reference+4,4)==0 && memcmp(high,reference,4)==0);
              puts("PASS: failed/throwing handlers restore context, do not publish, and retry successfully");
              [scaled setCacheMode:NSImageCacheAlways];
              invalidateDuringDraw=YES;
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==9);
              invalidateDuringDraw=NO;
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==10);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==10);
              puts("PASS: invalidation during drawing prevents stale cache publication");
              NSAppearance *previous=[[NSApp appearance] retain];
              NSAppearance *alternate=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
              [NSApp setAppearance:alternate];
              assert([NSAppearance currentAppearance]==alternate);
              memset(pixels,0,sizeof(pixels));
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==11 && memcmp(low,reference+8,4)==0);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==11);
              [NSApp setAppearance:previous];
              [previous release];
              assert([NSAppearance currentAppearance]==originalAppearance);
              memset(pixels,0,sizeof(pixels));
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==11 && memcmp(low,reference+4,4)==0);
              puts("PASS: appearance change renders new tint; restoring appearance reuses original tint");
          }
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
