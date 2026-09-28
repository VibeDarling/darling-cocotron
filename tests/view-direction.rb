# Actual view direction accessors, controlled application and invalidation hooks.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
source=File.read(File.expand_path('../AppKit/NSView.m',__dir__))
methods=source.scan(/^- \([^\n]+.*?^\}/m).select{|m| m.lines.first.match?(/ (userInterfaceLayoutDirection|setUserInterfaceLayoutDirection:)/)}.join("\n")
abort 'accessors missing' unless methods.include?('setUserInterfaceLayoutDirection:')
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  typedef NSInteger NSUserInterfaceLayoutDirection;
  enum { NSUserInterfaceLayoutDirectionLeftToRight=0, NSUserInterfaceLayoutDirectionRightToLeft=1 };
  static NSInteger appDirection;
  @interface App : NSObject @end
  @implementation App
  - (NSInteger)userInterfaceLayoutDirection { return appDirection; }
  @end
  static App *NSApp;
  @interface View : NSObject {
    NSInteger _userInterfaceLayoutDirection; BOOL _hasUserInterfaceLayoutDirection;
  @public unsigned layouts, displays;
  }
  - (NSInteger)userInterfaceLayoutDirection;
  - (void)setUserInterfaceLayoutDirection:(NSInteger)direction;
  @end
  @implementation View
  - (void)setNeedsLayout:(BOOL)value { assert(value); ++layouts; }
  - (void)setNeedsDisplay:(BOOL)value { assert(value); ++displays; }
  ACTUAL_METHODS
  @end
  int main(void) {
    @autoreleasepool {
      View *a=[View new], *b=[View new];
      assert([a userInterfaceLayoutDirection]==0);
      NSApp=[App new]; appDirection=1;
      assert([a userInterfaceLayoutDirection]==1 && [b userInterfaceLayoutDirection]==1);
      [a setUserInterfaceLayoutDirection:0];
      assert([a userInterfaceLayoutDirection]==0 && [b userInterfaceLayoutDirection]==1);
      appDirection=0; assert([b userInterfaceLayoutDirection]==0);
      [a setUserInterfaceLayoutDirection:1];
      assert([a userInterfaceLayoutDirection]==1 && [b userInterfaceLayoutDirection]==0);
      assert(a->layouts==2 && a->displays==2 && !b->layouts && !b->displays);
      [NSApp release]; NSApp=nil;
      assert([a userInterfaceLayoutDirection]==1 && [b userInterfaceLayoutDirection]==0);
      [a release]; [b release];
      puts("PASS: application fallback, explicit LTR/RTL, independent state and invalidation");
    }
  }
OBJC
program=program.sub('ACTUAL_METHODS'){methods}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'headers missing' unless status.success?
Dir.mktmpdir('view-direction') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'test failed' unless system(output)
end
