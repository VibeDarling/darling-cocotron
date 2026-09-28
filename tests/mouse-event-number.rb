# Actual mouse initializers/accessors on a GNUstep host, with a stub superclass.
# Usage: ruby mouse-event-number.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0); root=ARGV[1] || File.expand_path('..',__dir__)
source=File.read(File.join(root,'AppKit/NSEvent.subproj/NSEvent_mouse.m'))
header=File.read(File.join(root,'AppKit/NSEvent_mouse.h'))
ivars=header[/@interface NSEvent_mouse : NSEvent \{(.*?)\n\}/m,1]
methods=source.scan(/^- .*?^\}/m).select { |m| m.include?('eventNumber:') || m.match?(/^- \(NSInteger\) (eventNumber|clickCount|trackingNumber)/) || m.start_with?('- (void *) userData') }
abort 'missing event number accessor' unless methods.any? { |m| m.start_with?('- (NSInteger) eventNumber') }
declarations=methods.map { |m| m.split('{',2).first.strip+';' }.join("\n")
program=<<~OBJC
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <stdint.h>
  typedef NSUInteger NSEventType, NSEventModifierFlags;
  enum { NSMouseEntered=8, NSMouseExited=9 };
  @class NSWindow, NSGraphicsContext;
  static id NSApp;
  @interface NSObject (WindowLookup)
  - (id)windowWithWindowNumber:(NSInteger)number;
  @end
  @interface NSEvent : NSObject { @protected int _type; }
  - (instancetype)initWithType:(NSEventType)t location:(NSPoint)p modifierFlags:(NSEventModifierFlags)f window:(NSWindow *)w;
  @end
  @implementation NSEvent
  - (instancetype)initWithType:(NSEventType)t location:(NSPoint)p modifierFlags:(NSEventModifierFlags)f window:(NSWindow *)w { if ((self=[super init])) _type=t; return self; }
  @end
  @interface NSEvent_mouse : NSEvent { #{ivars} }
  #{declarations}
  @end
  @implementation NSEvent_mouse
  #{methods.join("\n")}
  @end
  int main(void) {
      @autoreleasepool {
          NSInteger values[]={0,1,-1,INT32_MAX,(NSInteger)INT64_C(0x123456789)};
          for (unsigned i=0;i<sizeof(values)/sizeof(*values);++i) {
              NSEvent_mouse *mouse=[[NSEvent_mouse alloc] initWithType:1 location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:values[i] clickCount:3 pressure:0];
              assert([mouse eventNumber]==values[i] && [mouse clickCount]==3);
              [mouse release];
              NSEvent_mouse *tracking=[[NSEvent_mouse alloc] initWithType:8 location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:values[i] trackingNumber:71 userData:(void*)0x1234];
              assert([tracking eventNumber]==values[i] && [tracking trackingNumber]==71 && [tracking userData]==(void*)0x1234);
              [tracking release];
          }
          puts("PASS: mouse/tracking event numbers and existing fields survive initialization");
      }
  }
OBJC
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('event-number') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'test failed' unless system(output,rlimit_core:0)
end
