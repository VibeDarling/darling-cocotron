# Actual backend method, with instrumented surface/font/paint/allocation adapters.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
source=File.read(File.expand_path('../Onyx2D/O2Context_builtin_FT.m',__dir__))
method=source[/- \(void\) showGlyphs:.*?^\}/m] or abort 'method missing'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <stdint.h>
  #include <math.h>
  typedef double O2Float;
  typedef NSSize O2Size;
  typedef uint16_t O2Glyph;
  typedef void *FT_Face;
  typedef int FT_Error, O2Paint;
  typedef struct { double a,b,c,d,tx,ty; } O2AffineTransform;
  static int allocs,frees,locks,unlocks,paints,glyphCalls,concats,defaults;
  static int failAlloc,missingFace,failSize;
  static O2Paint paint;
  static void *allocate(size_t n) { allocs++; return failAlloc ? NULL : malloc(n); }
  static void dispose(void *p) { if (p) frees++; free(p); }
  #define malloc allocate
  #define free dispose
  #define NSLog(...) ((void)0)
  @interface O2FreeTypeCachedGlyph : NSObject { @public int bitmap; double left,top; long advance; } @end
  @implementation O2FreeTypeCachedGlyph @end
  @interface O2Font_freetype : NSObject
  - (FT_Face)face;
  - (O2FreeTypeCachedGlyph *)rasterizeGlyph:(O2Glyph)glyph pointSize:(double)size;
  @end
  @implementation O2Font_freetype
  - (FT_Face)face { return missingFace ? NULL : (void *)1; }
  - (O2FreeTypeCachedGlyph *)rasterizeGlyph:(O2Glyph)glyph pointSize:(double)size { glyphCalls++; return nil; }
  @end
  typedef struct { id _font; void *_fillColor; } O2GState;
  @interface Context : NSObject { @public void *_surface; O2GState state; }
  - (void)establishFontStateInDeviceIfDirty;
  - (void)showGlyphs:(const O2Glyph *)g advances:(const O2Size *)a count:(NSUInteger)n;
  @end
  static void O2SurfaceLock(void *s) { locks++; }
  static void O2SurfaceUnlock(void *s) { unlocks++; }
  static O2GState *O2ContextCurrentGState(Context *c) { return &c->state; }
  static O2Paint *paintFromColor(void *c) { paints++; return &paint; }
  static void O2PaintRelease(O2Paint *p) { assert(p==&paint && paints==1); paints--; }
  static O2AffineTransform O2ContextGetTextRenderingMatrix(Context *c) { return (O2AffineTransform){1,0,0,1,0,0}; }
  static NSPoint O2PointApplyAffineTransform(NSPoint p,O2AffineTransform t) { return p; }
  static O2AffineTransform O2AffineTransformMakeScale(double x,double y) { return (O2AffineTransform){x,0,0,y,0,0}; }
  static O2Size O2SizeMake(double x,double y) { return NSMakeSize(x,y); }
  static O2Size O2SizeApplyAffineTransform(O2Size s,O2AffineTransform t) { return NSMakeSize(s.width*t.a,s.height*t.d); }
  static double O2GStatePointSize(O2GState *s) { return 12; }
  static FT_Error FT_Set_Char_Size(FT_Face f,int x,double y,int a,int b) { return failSize; }
  static void O2ContextGetDefaultAdvances(Context *c,const O2Glyph *g,O2Size *a,size_t n) {
      defaults++; for (size_t i=0;i<n;i++) a[i]=NSMakeSize(11,0);
  }
  static void O2ContextConcatAdvancesToTextMatrix(Context *c,const O2Size *a,size_t n) {
      concats++; assert(n==2 && a && a[0].width==(defaults ? 11 : 3));
  }
  static void renderFreeTypeBitmap(Context *c,void *s,int *b,double x,double y,O2Paint *p) { assert(0); }
  @implementation Context
  - (void)establishFontStateInDeviceIfDirty {}
  ACTUAL_METHOD
  @end
  static void reset(void) {
      allocs=frees=locks=unlocks=paints=glyphCalls=concats=defaults=0;
      failAlloc=missingFace=failSize=0;
  }
  int main(void) {
      @autoreleasepool {
          Context *c=[Context new]; O2Font_freetype *font=[O2Font_freetype new]; c->state._font=font;
          O2Glyph glyphs[]={1,2}; O2Size advances[]={{3,0},{4,0}};
          for (int explicit=0;explicit<2;explicit++) {
              for (int failure=0;failure<3;failure++) {
                  reset(); missingFace=failure==1; failSize=failure==2;
                  [c showGlyphs:glyphs advances:explicit ? advances : NULL count:2];
                  assert(allocs==!explicit && frees==!explicit && locks==1 && unlocks==1 && paints==0);
                  assert(glyphCalls==(failure ? 0 : 2) && concats==!failure);
                  assert(defaults==(!failure && !explicit));
              }
          }
          reset(); failAlloc=1;
          [c showGlyphs:glyphs advances:NULL count:2];
          assert(allocs==1 && frees==0 && locks==0 && paints==0 && glyphCalls==0);
          reset();
          [c showGlyphs:glyphs advances:NULL count:NSUIntegerMax];
          [c showGlyphs:NULL advances:NULL count:2];
          [c showGlyphs:glyphs advances:NULL count:0];
          assert(allocs==0 && locks==0 && paints==0 && concats==0);
          [font release]; [c release];
          puts("Actual FreeType method allocation, lock, paint and failure cleanup tests passed (adapters)");
      }
  }
OBJC
program=program.sub('ACTUAL_METHOD') { method }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('freetype-draw-cleanup') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base','-lobjc','-lm','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
