# Execute the actual cache-fill block with controlled drawing/focus adapters.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
source=File.read(File.expand_path('../AppKit/NSImage.m',__dir__))
block=source[/        if \(!_cacheIsValid\) \{.*?\n\n        return [^;]+;/m]
abort 'cache block missing' unless block
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static BOOL drawResult;
  static BOOL throwDraw;
  static BOOL throwSize;
  static unsigned draws, locks, unlocks, removals;
  static BOOL render(void) {
    ++draws;
    if (throwDraw) [NSException raise:@"DrawFailure" format:@"fixture"];
    return drawResult;
  }
  @interface Rep : NSObject @end
  @implementation Rep
  - (BOOL)drawAtPoint:(NSPoint)point { return render(); }
  @end
  @interface Image : NSObject { @public BOOL _cacheIsValid, scales; id cachedRep; }
  @end
  @implementation Image
  - (NSSize)size {
    if (throwSize) [NSException raise:@"SizeFailure" format:@"fixture"];
    return NSMakeSize(20,20);
  }
  - (BOOL)scalesWhenResized { return scales; }
  - (void)lockFocusOnRepresentation:(id)rep { ++locks; }
  - (void)unlockFocus { ++unlocks; }
  - (void)removeRepresentation:(id)rep { assert(rep==cachedRep); ++removals; }
  - (BOOL)drawRepresentation:(id)rep inRect:(NSRect)rect { return render(); }
  - (id)fill:(Rep *)uncached {
    id cached=cachedRep;
    BLOCK
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
      [image->cachedRep release]; [rep release]; [image release];
    }
  }
OBJC
program.sub!('BLOCK'){block}
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('image-cache') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'cache regression failed' unless system(output,rlimit_core:0)
end
puts 'PASS: failed caches discarded; source returned on failure; exception cleanup, retry and reuse, scaled and unscaled'
