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
image_copy=source[/- copyWithZone:.*?\n\}/m]
abort 'image copy method missing' unless image_copy
image_copy=image_copy.sub('NSImage *result','DeferredFactoryProbe *result')
{'_drawingHandlerRepCache'=>'_probeDrawingCache','_scaledRepCache'=>'_probeScaledCache',
 '_accessibilityDescription'=>'_probeDescription','_symbolConfiguration'=>'_probeSymbol'}.each do |a,b|
  image_copy=image_copy.gsub(a,b)
end
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
  #import <AppKit/NSWindow.h>
  #import "#{root}/AppKit/NSImageDrawingCache.m"
  #include <string.h>
  static unsigned cacheInstances, cacheDestructions;
  @interface TrackedDrawingCache : NSImageDrawingCache @end
  @implementation TrackedDrawingCache
  - (instancetype)init { if ((self=[super init])) ++cacheInstances; return self; }
  - (void)dealloc { ++cacheDestructions; [super dealloc]; }
  @end
  @implementation DeferredProbeImageRep (CandidateDrawingWrappers)
  #{rep_methods}
  @end
  // Staged NSImage does not have the candidate's new cache ivar. Supply storage
  // in this subclass; the extracted lookup/population uses the same accessor.
  @interface DeferredFactoryProbe : NSImage { NSImageDrawingCache *_probeDrawingCache; NSUInteger _probeLastRasterCost; id _probeScaledCache, _probeDescription, _probeSymbol; }
  - (NSUInteger)probeLastRasterCost;
  @end
  @implementation DeferredFactoryProbe
  - (NSImageDrawingCache *)_drawingHandlerCache {
      if (_probeDrawingCache==nil) _probeDrawingCache=[TrackedDrawingCache new];
      return _probeDrawingCache;
  }
  - (void)dealloc { [_probeDrawingCache release]; [_probeScaledCache release]; [_probeDescription release]; [_probeSymbol release]; [super dealloc]; }
  - (NSUInteger)probeLastRasterCost { return _probeLastRasterCost; }
  #{factory}
  #{cache_mode}
  #{image_copy}
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
      CGContextRef backing=[[(NSCachedImageRep *)cachedRep window] graphicsContext].graphicsPort;
      _probeLastRasterCost=CGBitmapContextGetBytesPerRow(backing)*CGBitmapContextGetHeight(backing);
      if (getenv("TEST_EXPECT_WINDOW_SCALE")) {
          CGFloat expected=strtod(getenv("TEST_EXPECT_WINDOW_SCALE"),NULL);
          NSRect backingRect=[(NSCachedImageRep *)cachedRep rect];
          CGFloat actual=CGBitmapContextGetWidth(backing)/backingRect.size.width;
          printf("Intermediate window backing: expected=%g actual=%g\\n",expected,actual);
          assert(fabs(actual-expected)<0.000001);
      }
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
          {
              unsigned char pixel[4]={0};
              CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
              CGContextRef invalidPort=CGBitmapContextCreate(pixel,1,1,8,4,space,kCGImageAlphaPremultipliedLast);
              CGColorSpaceRelease(space);
              assert(invalidPort!=NULL);
              NSGraphicsContext *invalidContext=[NSGraphicsContext graphicsContextWithGraphicsPort:invalidPort flipped:NO];
              [NSGraphicsContext setCurrentContext:invalidContext];
              __block unsigned invalidCalls=0;
              DeferredFactoryProbe *invalid=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,20)
                  flipped:NO drawingHandler:^BOOL(NSRect rect) { ++invalidCalls; return YES; }];
              CGFloat invalidWidths[]={0,NAN,INFINITY,(CGFloat)INT32_MAX+1};
              for (unsigned n=0;n<4;++n) {
                  [invalid probeCache:[[invalid representations] objectAtIndex:0]
                      source:NSZeroRect destination:NSMakeRect(0,0,invalidWidths[n],20)];
                  assert(invalidCalls==0);
                  assert([NSGraphicsContext currentContext]==invalidContext);
                  assert([invalid probeLastRasterCost]==0);
              }
              [NSGraphicsContext setCurrentContext:nil];
              CGContextRelease(invalidPort);
              puts("PASS: zero and non-finite destination sizes skip handler rendering");
          }
          // Opt-in because this regression allocates an over-budget raster.
          if (getenv("TEST_LARGE_DESTINATION")) {
              const size_t side=2051, raster=2049;
              unsigned char *pixel=calloc(side*side,4);
              assert(pixel!=NULL);
              CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
              CGContextRef largePort=CGBitmapContextCreate(pixel,side,side,8,side*4,space,kCGImageAlphaPremultipliedLast);
              CGColorSpaceRelease(space);
              assert(largePort!=NULL);
              [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:largePort flipped:NO]];
              __block CGFloat density=0;
              __block unsigned largeCalls=0;
              DeferredFactoryProbe *large=[DeferredFactoryProbe imageWithSize:NSMakeSize(20,20)
                  flipped:NO drawingHandler:^BOOL(NSRect rect) {
                      ++largeCalls;
                      density=CGContextGetCTM(NSCurrentGraphicsPort()).a;
                      CGContextSetRGBFillColor(NSCurrentGraphicsPort(),1,0,0,1);
                      CGContextFillRect(NSCurrentGraphicsPort(),CGRectMake(0,0,20,20));
                      CGContextSetRGBFillColor(NSCurrentGraphicsPort(),0,0,1,1);
                      CGContextFillRect(NSCurrentGraphicsPort(),CGRectMake(0,0,20,8));
                      CGContextSetRGBFillColor(NSCurrentGraphicsPort(),0,1,0,1);
                      CGContextFillRect(NSCurrentGraphicsPort(),CGRectMake(1000.0/102.45,0,1.0/102.45,20));
                      return YES;
                  }];
              [large probeCache:[[large representations] objectAtIndex:0]
                  source:NSZeroRect destination:NSMakeRect(1,1,raster,raster)];
              printf("Large destination: expected density=102.45 observed=%g\\n",density);
              assert(fabs(density-102.45)<0.000001);
              assert([[large _drawingHandlerCache] byteCost]==0);
              size_t painted=0;
              for (size_t y=0;y<side;++y) for (size_t x=0;x<side;++x) {
                  unsigned char *p=pixel+(y*side+x)*4;
                  BOOL nonzero=p[0]||p[1]||p[2]||p[3];
                  assert(nonzero==(x>0 && x<side-1 && y>0 && y<side-1));
                  if (nonzero) ++painted;
              }
              assert(painted==raster*raster);
              assert(memcmp(pixel+(10*side+10)*4,reference,4)==0);
              assert(memcmp(pixel+((side-10)*side+10)*4,reference+4,4)==0);
              assert(memcmp(pixel+(10*side+1001)*4,reference+8,4)==0);
              assert(memcmp(pixel+(10*side+1000)*4,reference,4)==0);
              assert(memcmp(pixel+(10*side+1002)*4,reference,4)==0);
              memset(pixel,0,side*side*4);
              [large probeCache:[[large representations] objectAtIndex:0]
                  source:NSZeroRect destination:NSMakeRect(1,1,raster,raster)];
              assert(largeCalls==2 && fabs(density-102.45)<0.000001);
              assert([[large _drawingHandlerCache] byteCost]==0);
              assert(memcmp(pixel+(10*side+1001)*4,reference+8,4)==0);
              [NSGraphicsContext setCurrentContext:nil];
              CGContextRelease(largePort);
              free(pixel);
              puts("PASS: full over-budget raster extent, orientation and single-pixel detail");
              puts("PASS: over-budget destination preserves density without retaining raster");
          }
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
          assert([scaled probeLastRasterCost]>0);
          assert([[scaled _drawingHandlerCache] byteCost]==[scaled probeLastRasterCost]);
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
              DeferredFactoryProbe *copied=[scaled copy];
              assert([copied _drawingHandlerCache]!=[scaled _drawingHandlerCache]);
              assert([[copied _drawingHandlerCache] byteCost]==0);
              [copied probeCache:[[copied representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==12);
              [copied setCacheMode:NSImageCacheAlways];
              [copied probeCache:[[copied representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==13);
              unsigned beforeDestruction=cacheDestructions;
              [copied release];
              assert(cacheDestructions==beforeDestruction+1);
              [scaled probeCache:[[scaled representations] objectAtIndex:0] source:source destination:destination];
              assert(renderCalls==13);
              puts("PASS: copied image starts uncached, invalidates independently, and releases its cache");
          }
          [NSGraphicsContext setCurrentContext:nil];
          CGContextRelease(port);
          }
          puts("PASS: temporary cache preserves destination scale");
      }
  }
  static void verifyFactoryCacheTeardown(void) {
      assert(cacheInstances==cacheDestructions);
      puts("PASS: all image-owned caches released after pool teardown");
  }
OBJC
test.sub!('// FACTORY_INSERTION_POINT', insertion)
Dir.mktmpdir('deferred-factory-source-') do |dir|
  path="#{dir}/probe.m"
  File.write(path,"#define TEST_DEFERRED_FACTORY 1\n"+test)
  abort 'build failed' unless system({'COCOTRON_DIR'=>root},'ruby',ARGV.fetch(0),path)
end
