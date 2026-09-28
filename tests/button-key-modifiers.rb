# Native GNUstep test of the actual NSButton method with controlled events.
# Usage: ruby button-key-modifiers.rb GNUSTEP_ROOT [NSButton.m]
require 'tmpdir'
require 'open3'
sdk = ARGV.fetch(0)
source = File.read(ARGV[1] || File.expand_path('../AppKit/NSButton.m', __dir__))
method = source[/^- \(BOOL\) performKeyEquivalent:.*?^\}/m]
abort 'method missing' unless method
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  enum { NSShiftKeyMask=1<<17, NSControlKeyMask=1<<18,
         NSAlternateKeyMask=1<<19, NSCommandKeyMask=1<<20 };
  static unsigned eventFlags, buttonFlags, clicks;
  static BOOL enabled=YES, matching=YES;
  @interface NSEvent : NSObject
  - (NSString *)charactersIgnoringModifiers;
  - (unsigned)modifierFlags;
  @end
  @implementation NSEvent
  - (NSString *)charactersIgnoringModifiers { return matching ? @"x" : @"y"; }
  - (unsigned)modifierFlags { return eventFlags; }
  @end
  @interface Button : NSObject
  - (BOOL)isEnabled;
  - (unsigned)keyEquivalentModifierMask;
  - (NSString *)keyEquivalent;
  - (void)performClick:(id)sender;
  - (BOOL)performKeyEquivalent:(NSEvent *)event;
  @end
  @implementation Button
  - (BOOL)isEnabled { return enabled; }
  - (unsigned)keyEquivalentModifierMask { return buttonFlags; }
  - (NSString *)keyEquivalent { return @"x"; }
  - (void)performClick:(id)sender { ++clicks; }
  ACTUAL_METHOD
  @end
  int main(void) {
      @autoreleasepool {
          Button *button=[Button new]; NSEvent *event=[NSEvent new];
          for (unsigned b=0;b<16;++b) for(unsigned e=0;e<16;++e) {
              buttonFlags=b<<17; eventFlags=(e<<17) | (1<<16) | (1<<21);
              clicks=0;
              assert([button performKeyEquivalent:event] == (b==e));
              assert(clicks == (b==e));
          }
          buttonFlags=eventFlags=NSCommandKeyMask; clicks=0; enabled=NO;
          assert(![button performKeyEquivalent:event] && clicks==0);
          enabled=YES; matching=NO;
          assert(![button performKeyEquivalent:event] && clicks==0);
          [event release]; [button release];
          puts("PASS: 256 modifier combinations, unrelated flags, disabled and wrong key");
      }
  }
OBJC
program = program.sub('ACTUAL_METHOD') { method }
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'GCC headers unavailable' unless status.success?
Dir.mktmpdir('button-modifiers') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'test failed' unless system(output, rlimit_core: 0)
end
