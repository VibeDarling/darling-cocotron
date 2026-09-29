# Execute actual candidate run accessors while recording copy requests.
require 'tmpdir'
require 'open3'
candidate = File.expand_path('../CoreText/CTRun.m', __dir__)
source = File.read(candidate)
functions = ['static CFRange normalizedRange', 'void CTRunGetGlyphs',
             'void CTRunGetAdvances', 'void CTRunGetPositions',
             'void CTRunGetBaseAdvancesAndOrigins'].map do |signature|
  source[/#{Regexp.escape(signature)}\(.*?^\}/m] or abort "missing #{signature}"
end.join("\n")
program = <<~'C'
  #include <assert.h>
  #include <stddef.h>
  #include <stdint.h>
  #include <stdio.h>
  typedef long CFIndex;
  typedef void *CTRunRef;
  typedef uint16_t CGGlyph;
  typedef struct { double x,y; } CGPoint;
  typedef struct { double width,height; } CGSize;
  typedef struct { CFIndex location,length; } CFRange;
  static CFRange CFRangeMake(CFIndex a,CFIndex b) { return (CFRange){a,b}; }
  static CGGlyph glyphs[4];
  static CGPoint positions[4];
  static CGSize advances[4];
  static size_t lastBytes, copies;
  static CFIndex CTRunGetGlyphCount(CTRunRef run) { return 4; }
  static const CGGlyph *CTRunGetGlyphsPtr(CTRunRef run) { return glyphs; }
  static const CGPoint *CTRunGetPositionsPtr(CTRunRef run) { return positions; }
  static const CGSize *CTRunGetAdvancesPtr(CTRunRef run) { return advances; }
  static void *recordCopy(void *destination,const void *source,size_t bytes) {
      lastBytes = bytes; copies++; return destination;
  }
  #define memcpy recordCopy
  ACTUAL_FUNCTIONS
  int main(void) {
      CGGlyph out[4]; CGSize a[4]; CGPoint p[4];
      CTRunGetGlyphs((void *)1,CFRangeMake(1,0),out);
      assert(lastBytes == 3*sizeof(CGGlyph));
  #ifdef CANDIDATE
      size_t before = copies;
      CTRunGetGlyphs((void *)1,CFRangeMake(0,-1),out);
      CTRunGetGlyphs((void *)1,CFRangeMake(-1,1),out);
      CTRunGetGlyphs((void *)1,CFRangeMake(5,1),out);
      CTRunGetGlyphs((void *)1,CFRangeMake(4,0),out);
      CTRunGetBaseAdvancesAndOrigins((void *)1,CFRangeMake(5,1),a,p);
      CTRunGetBaseAdvancesAndOrigins((void *)1,CFRangeMake(0,-1),a,p);
      assert(copies == before);
      CTRunGetBaseAdvancesAndOrigins((void *)1,CFRangeMake(2,0),a,p);
      assert(copies == before+2 && lastBytes == 2*sizeof(CGPoint));
      CTRunGetGlyphs((void *)1,CFRangeMake(3,99),out);
      assert(lastBytes == sizeof(CGGlyph));
      puts("PASS: candidate rejects invalid/empty ranges without copying; remainder/clamping semantics preserved");
  #else
      CTRunGetGlyphs((void *)1,CFRangeMake(0,-1),out);
      assert(lastBytes == SIZE_MAX-1);
      puts("CONFIRMED: negative length becomes SIZE_MAX-1 requested bytes (copy intercepted)");
      CTRunGetGlyphs((void *)1,CFRangeMake(5,1),out);
      assert(lastBytes == 0);
      size_t before = copies;
      CTRunGetBaseAdvancesAndOrigins((void *)1,CFRangeMake(5,1),a,p);
      assert(copies == before+2 && lastBytes == 4*sizeof(CGPoint));
      puts("CONFIRMED: invalid range is empty in direct accessor but expands to full run after double normalization");
  #endif
  }
C
program = program.sub('ACTUAL_FUNCTIONS') { functions }
Dir.mktmpdir('coretext-run-ranges') do |dir|
  input=File.join(dir,'probe.c'); output=File.join(dir,'probe')
  File.write(input,program)
  abort 'compile failed' unless system('clang','-std=c11','-O2','-fsanitize=address,undefined',
    *(candidate ? ['-DCANDIDATE'] : []),input,'-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
