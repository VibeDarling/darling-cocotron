# Execute complete candidate CTLine/CTRun sources with GNUstep CF/font adapters.
# Usage: ruby tests/line-host.rb GNUSTEP_ROOT
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
root=File.expand_path('..',__dir__)
sources=%w[CTLine CTRun].map { |name| File.read("#{root}/CoreText/#{name}.m").gsub(/^#(?:import|include).*\n/,'') }.join("\n")
declarations=%w[CTLine CTRun].map do |name|
  File.read("#{root}/CoreText/include/CoreText/#{name}.h").scan(/CORETEXT_EXPORT\s+([^;]+);/).flatten.join(";\n")+";\n"
end.join.gsub('_Nullable','')
internal=File.read("#{root}/CoreText/KTCoreTextInternal.h").gsub(/^#import.*\n/,'')
program=File.read(File.join(__dir__,'line-host-support.h'))+declarations+internal+sources
program += <<~'OBJC'
  static void *registerTypes(void *unused) {
      for (int i=0;i<10000;i++) {
          assert(CTLineGetTypeID()!=CTRunGetTypeID());
          assert(CTLineGetTypeID()!=0 && CTRunGetTypeID()!=0);
      }
      return NULL;
  }
  int main(void) {
      @autoreleasepool {
          pthread_t workers[8];
          for (int i=0;i<8;i++) assert(pthread_create(&workers[i],NULL,registerTypes,NULL)==0);
          for (int i=0;i<8;i++) assert(pthread_join(workers[i],NULL)==0);
          assert(registeredClasses==2);
          NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"abcd" attributes:@{@"font":@5}];
          [text addAttribute:@"font" value:@7 range:NSMakeRange(2,2)];
          CTLineRef line=CTLineCreateWithAttributedString(text);
          assert(line && CFGetTypeID(line)==CTLineGetTypeID());
          assert(CTLineGetTypeID()!=CTRunGetTypeID() && registeredClasses==2);
          assert(CTLineGetGlyphCount(line)==4 && CTLineGetTypographicBounds(line,NULL,NULL,NULL)==24);
          CFArrayRef runs=CTLineGetGlyphRuns(line); assert(CFArrayGetCount(runs)==2);
          CTRunRef run=CFArrayGetValueAtIndex(runs,1);
          assert(CFGetTypeID(run)==CTRunGetTypeID() && CTRunGetGlyphCount(run)==2);
          assert(CTRunGetPositionsPtr(run)[0].x==10 && CTRunGetStringIndicesPtr(run)[0]==2);
          CFRelease(line); assert(liveObjects==0);
          // Two run allocations followed by the line wrapper. Fail each in turn.
          for (int fail=1;fail<=3;fail++) {
              allocationCount=0; failAllocation=fail;
              assert(CTLineCreateWithAttributedString(text)==nil && liveObjects==0);
          }
          failAllocation=0; allocationCount=0;
          [text release];
          text=[[NSMutableAttributedString alloc] initWithString:@"" attributes:@{}];
          line=CTLineCreateWithAttributedString(text);
          assert(line && CTLineGetGlyphCount(line)==0);
          CFRelease(line); [text release]; assert(liveObjects==0);
          // Normalization may change glyph count, not the source UTF-16 range.
          NSAttributedString *composed=[[NSAttributedString alloc] initWithString:@"\u00e9" attributes:@{@"font":@5}];
          NSAttributedString *decomposed=[[NSAttributedString alloc] initWithString:@"e\u0301" attributes:@{@"font":@5}];
          CTLineRef a=CTLineCreateWithAttributedString(composed);
          CTLineRef b=CTLineCreateWithAttributedString(decomposed);
          assert(CTLineGetGlyphCount(a)==1 && CTLineGetGlyphCount(b)==1);
          assert(CTLineGetStringRange(a).length==1 && CTLineGetStringRange(b).length==2);
          CTRunRef ar=CFArrayGetValueAtIndex(CTLineGetGlyphRuns(a),0);
          CTRunRef br=CFArrayGetValueAtIndex(CTLineGetGlyphRuns(b),0);
          assert(CTRunGetGlyphsPtr(ar)[0]==CTRunGetGlyphsPtr(br)[0]);
          assert(CTRunGetStringRange(br).length==2 && CTRunGetStringIndicesPtr(br)[0]==0);
          CFRelease(a); CFRelease(b); [composed release]; [decomposed release];
          text=[[NSMutableAttributedString alloc] initWithString:@"e\u0301b" attributes:@{@"font":@5}];
          [text addAttribute:@"font" value:@7 range:NSMakeRange(1,2)];
          line=CTLineCreateWithAttributedString(text);
          runs=CTLineGetGlyphRuns(line); assert(CFArrayGetCount(runs)==3);
          for (CFIndex i=0;i<3;i++) {
              run=CFArrayGetValueAtIndex(runs,i);
              CFRange range=CTRunGetStringRange(run);
              assert(range.location==i && range.length==1);
          }
          // The line owns an immutable input snapshot, not the mutable source.
          [text replaceCharactersInRange:NSMakeRange(0,3) withString:@"z"];
          assert(CTLineGetStringRange(line).length==3);
          CFRelease(line); [text release]; assert(liveObjects==0);
          puts("Concurrent registration, NFC/source-index preservation, split-cluster ranges and input snapshot tests passed (host adapters)");
          puts("Whole-source ASCII runs, type separation, metrics, empty lines and wrapper-failure cleanup passed (host adapters)");
      }
  }
OBJC
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('line-host') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base','-lobjc','-lpthread','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
