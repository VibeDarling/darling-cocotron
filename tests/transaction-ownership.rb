# Compile complete transaction sources and the existing lifetime probe on
# GNUstep. Only the private thread-dictionary accessor is adapted.
# Usage: ruby tests/transaction-ownership.rb GNUSTEP_ROOT [BASELINE_REF]
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
root=File.expand_path('..',__dir__)
paths=%w[QuartzCore/include/QuartzCore/CATransaction.h QuartzCore/CATransactionGroup.h QuartzCore/CATransaction.m QuartzCore/CATransactionGroup.m]
parts=paths.map do |path|
  if ARGV[1]
    text,status=Open3.capture2('git','-C',root,'show',"#{ARGV[1]}:#{path}")
    abort text unless status.success?
  else
    text=File.read("#{root}/#{path}")
  end
  text.gsub(/^#import.*\n/,'')
end
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #define CA_EXPORT extern
  typedef double CFTimeInterval;
  #define NSCurrentThread() [NSThread currentThread]
  @interface NSThread (TransactionProbe)
  - (NSMutableDictionary *)sharedDictionary;
  @end
  @implementation NSThread (TransactionProbe)
  - (NSMutableDictionary *)sharedDictionary { return [self threadDictionary]; }
  @end
OBJC
program += parts.join("\n")
program += File.read("#{root}/tests/transaction-ownership.m").gsub(/^#import.*\n/,'')
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('transaction-ownership') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'lifetime probe failed' unless system(output,rlimit_core:0)
end
puts 'PASS: actual transaction sources, nested explicit commits and real host run-loop implicit commit release values'
