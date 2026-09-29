# Execute the actual range-intersection helper, independently of font shaping.
require 'tmpdir'
require 'open3'
source = File.read(File.expand_path('../CoreText/CTLine.m', __dir__))
method = source[/static CFRange clippedStringRange\(.*?^\}/m] or abort 'helper missing'
program = <<~'C'
  #include <assert.h>
  #include <limits.h>
  #include <stdio.h>
  typedef long CFIndex;
  typedef struct { CFIndex location,length; } CFRange;
  static CFRange CFRangeMake(CFIndex a,CFIndex b) { return (CFRange){a,b}; }
  #define MAX(a,b) ((a)>(b)?(a):(b))
  ACTUAL_METHOD
  int main(void) {
      // e + combining accent spans [0,2); new attributes start at the accent.
      // The following character at index 2 must not be swallowed into this run.
      CFRange r = clippedStringRange(CFRangeMake(0,2),1,3);
      assert(r.location == 1 && r.length == 1);
      for (long location=0;location<10;location++)
      for (long length=0;length<10;length++)
      for (long start=0;start<10;start++)
      for (long end=start;end<10;end++) {
          r = clippedStringRange(CFRangeMake(location,length),start,end);
          long low = MAX(start,location);
          long high = location+length < end ? location+length : end;
          long expected = high > low ? high-low : 0;
          assert(r.length == expected);
          if (expected) assert(r.location == low && r.location+r.length <= end);
      }
      r = clippedStringRange(CFRangeMake(1,LONG_MAX),2,LONG_MAX);
      assert(r.location == 2 && r.length == LONG_MAX-2);
      assert(clippedStringRange(CFRangeMake(-1,2),0,3).length == 0);
      assert(clippedStringRange(CFRangeMake(0,-1),0,3).length == 0);
      puts("Cluster/attribute range intersections and overflow checks passed");
  }
C
program = program.sub('ACTUAL_METHOD') { method }
Dir.mktmpdir('line-range-clipping') do |dir|
  input=File.join(dir,'probe.c'); output=File.join(dir,'probe')
  File.write(input,program)
  abort 'compile failed' unless system('clang','-std=c11','-O2','-fsanitize=address,undefined',input,'-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
