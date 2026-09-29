# Execute actual appendRun with controlled allocation and retaining-array calls.
require 'tmpdir'
require 'open3'
source = File.read(File.expand_path('../CoreText/CTLine.m', __dir__))
method = source[/static bool appendRun\(.*?^\}/m] or abort 'appendRun missing'
program = <<~'C'
  #include <assert.h>
  #include <stdbool.h>
  #include <stddef.h>
  #include <stdio.h>
  typedef double CGFloat;
  typedef struct Object { int refs; struct Object *storage; } Object;
  typedef Object *CFTypeRef, *CFDictionaryRef, *CFMutableArrayRef;
  static Object wrapper;
  static int failAllocation, inserts, releases;
  enum { KTRunAscentKey, KTRunDescentKey, KTRunLeadingKey };
  #define MAX(a,b) ((a)>(b)?(a):(b))
  static int KTCoreTextRunGetTypeID(void) { return 2; }
  static CFTypeRef createCoreTextObject(int type, CFDictionaryRef storage) {
      if (failAllocation) return NULL;
      wrapper = (Object){1,storage}; storage->refs++; return &wrapper;
  }
  static void CFRelease(CFTypeRef value) {
      assert(value && value->refs > 0); releases++;
      if (--value->refs == 0 && value->storage) CFRelease(value->storage);
  }
  static void CFArrayAppendValue(CFMutableArrayRef array, CFTypeRef value) {
      inserts++; value->refs++;
  }
  static CGFloat KTCoreTextDictionaryGetFloat(CFDictionaryRef run,int key) {
      return key == KTRunAscentKey ? 8 : key == KTRunDescentKey ? 3 : 1;
  }
  ACTUAL_METHOD
  int main(void) {
      Object array = {1,NULL}, run = {1,NULL};
      CGFloat ascent=2,descent=2,leading=2;
      assert(!appendRun(&array,NULL,&ascent,&descent,&leading));
      assert(inserts == 0 && releases == 0);
      failAllocation=1;
      assert(!appendRun(&array,&run,&ascent,&descent,&leading));
      assert(run.refs == 0 && inserts == 0 && releases == 1);
      assert(ascent == 2 && descent == 2 && leading == 2);
      failAllocation=0; run.refs=1;
      assert(appendRun(&array,&run,&ascent,&descent,&leading));
      assert(inserts == 1 && run.refs == 1 && wrapper.refs == 1);
      assert(ascent == 8 && descent == 3 && leading == 2);
      CFRelease(&wrapper);
      assert(run.refs == 0);
      puts("appendRun failure status, ownership and metrics tests passed");
  }
C
program = program.sub('ACTUAL_METHOD') { method }
Dir.mktmpdir('run-append-failure') do |dir|
  input=File.join(dir,'probe.c'); output=File.join(dir,'probe')
  File.write(input,program)
  abort 'compile failed' unless system('clang','-std=c11','-O2','-fsanitize=address,undefined',input,'-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
