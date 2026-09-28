# Execute the actual default-advance helper with a controlled font backend.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
source=File.read(File.expand_path('../Onyx2D/O2Context.m',__dir__))
method=source[/void O2ContextGetDefaultAdvances\(.*?^\}/m] or abort 'helper missing'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  typedef double O2Float;
  typedef uint16_t O2Glyph;
  typedef struct { double width,height; } O2Size;
  @interface O2Font : NSObject
  - (double)nativeSizeForSize:(double)size;
  @end
  @implementation O2Font
  - (double)nativeSizeForSize:(double)size { return size*1.5; }
  @end
  typedef struct { O2Font *font; double pointSize; } O2GState;
  typedef O2GState *O2ContextRef;
  static O2GState *O2ContextCurrentGState(O2ContextRef c) { return c; }
  static O2Font *O2GStateFont(O2GState *s) { return s->font; }
  static double O2GStatePointSize(O2GState *s) { return s->pointSize; }
  static double O2FontGetUnitsPerEm(O2Font *font) { return 1000; }
  static size_t calls, total;
  static void O2FontGetGlyphAdvances(O2Font *f,const O2Glyph *g,size_t n,int *out) {
      assert(n>0 && n<=256); calls++; total+=n;
      for (size_t i=0;i<n;i++) out[i]=g[i]*10-30;
  }
  ACTUAL_METHOD
  int main(void) {
      @autoreleasepool {
          O2Font *font=[O2Font new]; O2GState state={font,12};
          O2Glyph glyphs[1025]; O2Size advances[1026];
          for (size_t i=0;i<1025;i++) glyphs[i]=i;
          const size_t counts[]={0,1,255,256,257,512,1025};
          for (size_t c=0;c<sizeof(counts)/sizeof(counts[0]);c++) {
              size_t n=counts[c]; calls=total=0; advances[n]=(O2Size){123,456};
              O2ContextGetDefaultAdvances(&state,glyphs,advances,n);
              assert(total==n && calls==(n+255)/256);
              for (size_t i=0;i<n;i++) {
                  assert(advances[i].width==(glyphs[i]*10-30)*(18.0/1000));
                  assert(advances[i].height==0);
              }
              assert(advances[n].width==123 && advances[n].height==456);
          }
          [font release]; puts("Default advances match across 256-glyph chunk boundaries");
      }
  }
OBJC
program=program.sub('ACTUAL_METHOD') { method }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('default-advance-chunks') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
