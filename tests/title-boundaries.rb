# Exercise the production substring helper with real host attributed strings.
# This does not test rendering, measured widths, or target-runtime segmentation.
# Usage: ruby tests/title-boundaries.rb GNUSTEP_ROOT
require 'open3'
require 'tmpdir'
sdk = ARGV.fetch(0)
source = File.read(File.expand_path('../AppKit/NSStringDrawer.m', __dir__))
helper = source[/static NSAttributedString \*titleSubstring.*?(?=\n@implementation)/m]
abort 'helper not found' unless helper
program = "#import <Foundation/Foundation.h>\n#include <assert.h>\n" + helper
program += <<~'OBJC'
  int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSArray *samples = @[@"", @"abcdef", @"a\U0001F600b", @"ae\u0301z", @"\U0001F600e\u0301"];
    NSUInteger checked = 0;
    for (NSString *text in samples) {
      NSMutableAttributedString *input = [[[NSMutableAttributedString alloc] initWithString:text] autorelease];
      for (NSUInteger i = 0; i < [text length]; i++)
        [input addAttribute:@"index" value:@(i) range:NSMakeRange(i, 1)];
      for (NSUInteger start = 0; start <= [text length]; start++) {
        for (NSUInteger end = start; end <= [text length]; end++) {
          NSAttributedString *result = titleSubstring(input, NSMakeRange(start, end-start));
          NSUInteger expectedStart = start, expectedEnd = end;
          // Enumerate whole host-defined clusters independently of the helper.
          for (NSUInteger i = 0; i < [text length]; ) {
            NSRange cluster = [text rangeOfComposedCharacterSequenceAtIndex:i];
            assert(cluster.length > 0);
            if (start > i && start < NSMaxRange(cluster)) expectedStart = NSMaxRange(cluster);
            if (end > i && end < NSMaxRange(cluster)) expectedEnd = i;
            i = NSMaxRange(cluster);
          }
          NSUInteger length = expectedEnd > expectedStart ? expectedEnd-expectedStart : 0;
          assert([[result string] isEqualToString:[text substringWithRange:NSMakeRange(expectedStart,length)]]);
          for (NSUInteger i = 0; i < length; i++)
            assert([[result attribute:@"index" atIndex:i effectiveRange:NULL] unsignedIntegerValue] == expectedStart+i);
          checked++;
        }
      }
    }
    printf("PASS: %lu substring ranges and retained attributes\n", (unsigned long)checked);
    [pool drain];
  }
OBJC
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort unless status.success?
Dir.mktmpdir('title-boundaries') do |dir|
  input = "#{dir}/probe.m"; output = "#{dir}/probe"
  File.write(input, program)
  log, status = Open3.capture2e('clang', '-fobjc-runtime=gcc', '-fobjc-exceptions', '-fexceptions',
    '-fconstant-string-class=NSConstantString', "-I#{sdk}/usr/include/GNUstep", "-I#{gcc.strip}",
    input, "-L#{sdk}/usr/lib", "-Wl,-rpath,#{sdk}/usr/lib", '-lgnustep-base', '-lobjc', '-o', output)
  abort log unless status.success?
  abort 'boundary probe failed' unless system(output, rlimit_core: 0)
end
