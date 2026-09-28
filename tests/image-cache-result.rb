# Execute the actual cache-fill block with controlled drawing/focus adapters.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
source=File.read(File.expand_path('../AppKit/NSImage.m',__dir__))
block=source[/        if \(!_cacheIsValid\) \{.*?\n\n        return [^;]+;/m]
abort 'cache block missing' unless block
scaled_block=source[/    \[self lockFocusOnRepresentation: scaled\];.*?\n    return scaled;/m]
abort 'scaled cache block missing' unless scaled_block
temporary_block=source[/ +if \(cachedRep == nil\) \{.*?(?=\n\n +\/\/ A full bitmap)/m]
abort 'temporary cache block missing' unless temporary_block
rep_source=File.read(File.expand_path('../AppKit/NSImageRep.m',__dir__))
rep_methods=rep_source[/- \(BOOL\) drawAtPoint:.*?(?=\n- \(NSString \*\) description)/m]
abort 'representation drawing methods missing' unless rep_methods
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <math.h>
  // This host harness tests legacy reps. Block-backed destination caching is
  // exercised by the staged factory probe; entering that path here is an error.
  enum { NSImageCacheNever=3 };
  typedef struct { CGFloat a,b,c,d,tx,ty; } CGAffineTransform;
  @interface NSGraphicsContext : NSObject
  + (id)currentContext;
  @end
  @implementation NSGraphicsContext
  + (id)currentContext { abort(); }
  @end
  @interface NSAppearance : NSObject
  + (id)currentAppearance;
  @end
  @implementation NSAppearance
  + (id)currentAppearance { abort(); }
  @end
  @interface HandlerCache : NSObject
  - (NSUInteger)generation;
  - (id)representationForKey:(id)key;
  - (BOOL)setRepresentation:(id)rep forKey:(id)key byteCost:(NSUInteger)cost;
  @end
  @implementation HandlerCache
  - (NSUInteger)generation { abort(); }
  - (id)representationForKey:(id)key { abort(); }
  - (BOOL)setRepresentation:(id)rep forKey:(id)key byteCost:(NSUInteger)cost { abort(); }
  @end
  static BOOL drawResult;
  static BOOL throwDraw;
  static BOOL throwSize;
  static unsigned draws, locks, unlocks, removals;
  static unsigned additions;
  static unsigned graphicsDepth;
  typedef void *CGContextRef;
  static CGAffineTransform CGContextGetCTM(CGContextRef c) { abort(); }
  static CGContextRef NSCurrentGraphicsPort(void) { return NULL; }
  static void CGContextSaveGState(CGContextRef c) { ++graphicsDepth; }
  static void CGContextRestoreGState(CGContextRef c) { assert(graphicsDepth>0); --graphicsDepth; }
  static void CGContextTranslateCTM(CGContextRef c, CGFloat x, CGFloat y) {}
  static void CGContextScaleCTM(CGContextRef c, CGFloat x, CGFloat y) {}
  enum { scaledRepCacheCapacity=4, scaledRepCacheByteBudget=1024 };
  static NSUInteger scaledRepBytes(id rep) { return 16; }
  static NSUInteger scaledRepCacheBytes(NSArray *cache) { return [cache count]*16; }
  static BOOL render(void) {
    ++draws;
    if (throwDraw) [NSException raise:@"DrawFailure" format:@"fixture"];
    return drawResult;
  }
  @interface Rep : NSObject @end
  @implementation Rep
  REP_METHODS
  - (BOOL)draw { assert(graphicsDepth==2); return render(); }
  - (NSSize)size { return NSMakeSize(20,20); }
  @end
  typedef Rep NSImageRep;
  @interface NSCustomImageRep : Rep
  - (id)drawingHandler;
  @end
  @implementation NSCustomImageRep
  - (id)drawingHandler { abort(); }
  @end
  @interface NSCachedImageRep : Rep @end
  @implementation NSCachedImageRep
  - (id)initWithSize:(NSSize)size depth:(int)depth separate:(BOOL)separate alpha:(BOOL)alpha {
    return [super init];
  }
  @end
  @interface Image : NSObject { @public BOOL _cacheIsValid, scales, _isFlipped; id cachedRep, _backgroundColor; int _cacheMode; NSMutableArray *_scaledRepCache; }
  @end
  @implementation Image
  - (HandlerCache *)_drawingHandlerCache { abort(); }
  - (NSSize)size {
    if (throwSize) [NSException raise:@"SizeFailure" format:@"fixture"];
    return NSMakeSize(20,20);
  }
  - (BOOL)scalesWhenResized { return scales; }
  - (void)lockFocusOnRepresentation:(id)rep {
    assert(graphicsDepth==0); ++locks; CGContextSaveGState(NULL);
  }
  - (void)unlockFocus {
    assert(graphicsDepth==1); ++unlocks; CGContextRestoreGState(NULL);
  }
  - (void)removeRepresentation:(id)rep { assert(rep==cachedRep); ++removals; }
  - (void)addRepresentation:(id)rep { ++additions; }
  - (BOOL)drawRepresentation:(id)rep inRect:(NSRect)rect { return [rep drawInRect:rect]; }
  - (id)fill:(Rep *)uncached {
    id cached=cachedRep;
    BLOCK
  }
  - (id)fillScaled:(Rep *)sourceRep {
    id scaled=cachedRep;
    int pixelsWide=2, pixelsHigh=2;
    SCALED_BLOCK
  }
  - (void)fillTemporary:(Rep *)any cache:(BOOL)canCache source:(NSRect)source {
    NSRect rect=NSMakeRect(0,0,20,20);
    id cachedRep=nil;
    CGContextRef context;
    TEMPORARY_BLOCK
    assert(cachedRep!=nil);
  }
  @end
  int main(void) {
    @autoreleasepool {
      Image *image=[Image new]; Rep *rep=[Rep new];
      image->cachedRep=[Rep new];
      for (unsigned scaled=0;scaled<2;++scaled) {
        image->scales=scaled; image->_cacheIsValid=NO;
        draws=locks=unlocks=removals=0; drawResult=NO;
        assert([image fill:rep]==rep);
        assert(!image->_cacheIsValid && draws==1 && locks==1 && unlocks==1);
        assert(removals==1);
        drawResult=YES; assert([image fill:rep]==image->cachedRep);
        assert(image->_cacheIsValid && draws==2 && locks==2 && unlocks==2);
        assert([image fill:rep]==image->cachedRep); assert(draws==2 && locks==2 && unlocks==2 && removals==1);
        image->_cacheIsValid=NO; throwDraw=YES;
        BOOL caught=NO;
        @try { [image fill:rep]; }
        @catch(NSException *exception) { caught=[[exception name] isEqual:@"DrawFailure"]; }
        assert(caught && !image->_cacheIsValid && locks==3 && unlocks==3);
        assert(removals==2);
        throwDraw=NO; [image fill:rep];
        assert(image->_cacheIsValid && locks==4 && unlocks==4);
        image->_cacheIsValid=NO; throwSize=YES; caught=NO;
        @try { [image fill:rep]; }
        @catch(NSException *exception) { caught=[[exception name] isEqual:@"SizeFailure"]; }
        assert(caught && !image->_cacheIsValid && locks==5 && unlocks==5 && removals==3);
        throwSize=NO; assert([image fill:rep]==image->cachedRep);
        assert(image->_cacheIsValid && locks==6 && unlocks==6 && removals==3);
      }
      draws=locks=unlocks=0; drawResult=NO;
      assert([image fillScaled:rep]==nil);
      assert([image->_scaledRepCache count]==0 && locks==1 && unlocks==1);
      throwDraw=YES; BOOL caught=NO;
      @try { [image fillScaled:rep]; }
      @catch(NSException *exception) { caught=[[exception name] isEqual:@"DrawFailure"]; }
      assert(caught && [image->_scaledRepCache count]==0 && locks==2 && unlocks==2);
      throwDraw=NO; drawResult=YES;
      assert([image fillScaled:rep]==image->cachedRep);
      assert([image->_scaledRepCache count]==1 && locks==3 && unlocks==3);
      assert([[image->_scaledRepCache objectAtIndex:0] objectAtIndex:0]==rep);
      assert([[image->_scaledRepCache objectAtIndex:0] objectAtIndex:1]==image->cachedRep);
      [image->_scaledRepCache release];
      for (unsigned cache=0;cache<2;++cache) {
        for (unsigned flipped=0;flipped<2;++flipped) {
          for (unsigned crop=0;crop<2;++crop) {
            image->_isFlipped=flipped;
            NSRect source=crop ? NSMakeRect(1,2,3,4) : NSZeroRect;
            additions=draws=locks=unlocks=0; drawResult=NO;
            [image fillTemporary:rep cache:cache source:source];
            assert(additions==0 && draws==1 && locks==1 && unlocks==1);
            throwDraw=YES; caught=NO;
            @try { [image fillTemporary:rep cache:cache source:source]; }
            @catch(NSException *exception) { caught=[[exception name] isEqual:@"DrawFailure"]; }
            assert(caught && additions==0 && locks==2 && unlocks==2);
            throwDraw=NO; drawResult=YES;
            [image fillTemporary:rep cache:cache source:source];
            assert(additions==cache && locks==3 && unlocks==3);
          }
        }
      }
      [image->cachedRep release]; [rep release]; [image release];
    }
  }
OBJC
program.sub!('BLOCK'){block}
program.sub!('SCALED_BLOCK'){scaled_block}
program.sub!('TEMPORARY_BLOCK'){temporary_block}
program.sub!('REP_METHODS'){rep_methods}
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('image-cache') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-lm','-o',output)
  abort log unless status.success?
  abort 'cache regression failed' unless system(output,rlimit_core:0)
end
puts 'PASS: failed caches discarded; source returned on failure; exception cleanup, retry and reuse, scaled and unscaled'
