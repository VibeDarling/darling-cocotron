# Execute actual CGContextShowGlyphsAtPositions with controlled allocation/CG calls.
require 'tmpdir'
require 'open3'
source=File.read(ARGV.fetch(0,File.expand_path('../CoreGraphics/CGContext.m',__dir__)))
method=source[/void CGContextShowGlyphsAtPositions\(.*?^\}/m] or abort 'method missing'
program=<<~'C'
  #include <assert.h>
  #include <limits.h>
  #include <stdint.h>
  #include <stdlib.h>
  #include <stdio.h>
  typedef unsigned short CGGlyph;
  typedef struct { double x,y; } CGPoint;
  typedef struct { double width,height; } CGSize;
  typedef struct { double a,b,c,d,tx,ty; } CGAffineTransform;
  typedef struct { CGPoint point; CGAffineTransform matrix; } *CGContextRef;
  static int allocations, frees, draws, failed;
  static size_t requested;
  static CGSize captured[3];
  static CGSize CGSizeMake(double w,double h) { return (CGSize){w,h}; }
  static CGSize CGSizeApplyAffineTransform(CGSize s,CGAffineTransform t) {
      return CGSizeMake(t.a*s.width+t.c*s.height,t.b*s.width+t.d*s.height);
  }
  static CGPoint CGContextGetTextPosition(CGContextRef c) { return c->point; }
  static CGAffineTransform CGContextGetTextMatrix(CGContextRef c) { return c->matrix; }
  static void CGContextSetTextPosition(CGContextRef c,double x,double y) { c->point=(CGPoint){x,y}; }
  static void CGContextShowGlyphsWithAdvances(CGContextRef c,const CGGlyph *g,const CGSize *a,unsigned n) {
      assert(n<=3); draws++; for (unsigned i=0;i<n;i++) captured[i]=a[i];
  }
  static void *allocate(size_t n) { allocations++; requested=n; return failed ? NULL : malloc(n); }
  static void release(void *p) { frees++; free(p); }
  #define malloc allocate
  #define free release
  ACTUAL_METHOD
  int main(void) {
      struct { CGPoint point; CGAffineTransform matrix; } context={{10,20},{2,0,.5,3,0,0}};
      CGContextRef c=(CGContextRef)&context;
      CGGlyph glyphs[]={1,2,3}; CGPoint positions[]={{4,6},{9,8},{2,12}};
      CGContextShowGlyphsAtPositions(c,glyphs,positions,3);
      assert(allocations==1 && frees==1 && draws==1 && requested==3*sizeof(CGSize));
      assert(context.point.x==21 && context.point.y==38);
      assert(captured[0].width==5 && captured[0].height==2);
      assert(captured[1].width==-7 && captured[1].height==4);
      assert(captured[2].width==0 && captured[2].height==0);
      context.point=(CGPoint){10,20};
      CGContextShowGlyphsAtPositions(c,glyphs,positions,1);
      assert(allocations==2 && frees==2 && draws==2 && captured[0].width==0);
      failed=1; context.point=(CGPoint){10,20};
      CGContextShowGlyphsAtPositions(c,glyphs,positions,3);
      assert(allocations==3 && frees==2 && draws==2 && context.point.x==10 && context.point.y==20);
      // Do not allocate or dereference a huge array: allocator rejects it first.
      CGContextShowGlyphsAtPositions(c,glyphs,positions,UINT_MAX);
      if (UINT_MAX <= SIZE_MAX/sizeof(CGSize)) assert(allocations==4 && requested==(size_t)UINT_MAX*sizeof(CGSize));
      int before=allocations;
      CGContextShowGlyphsAtPositions(c,glyphs,positions,SIZE_MAX);
      CGContextShowGlyphsAtPositions(NULL,glyphs,positions,1);
      CGContextShowGlyphsAtPositions(c,NULL,positions,1);
      CGContextShowGlyphsAtPositions(c,glyphs,NULL,1);
      CGContextShowGlyphsAtPositions(c,glyphs,positions,0);
      assert(allocations==before && draws==2 && frees==2);
      puts("Positioned glyph heap ownership, failure guards and unchanged geometry passed");
  }
C
program=program.sub('ACTUAL_METHOD') { method }
Dir.mktmpdir('positioned-glyph-buffer') do |dir|
  input=File.join(dir,'probe.c'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-std=c11','-O2','-fsanitize=address,undefined',input,'-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
