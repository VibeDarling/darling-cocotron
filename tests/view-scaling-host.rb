# Actual scaling and bounds setter; controlled view/window storage, GNUstep
# notifications. Optional --overflow checks finite input producing infinite bounds.
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
root=File.expand_path('..',__dir__)
source=File.read("#{root}/AppKit/NSView.m")
methods=[/^- \(void\) scaleUnitSquareToSize:.*?^\}/m,/^- \(void\) setBounds:.*?^\}/m].map do |p|
  source[p] or abort 'method missing'
end.join("\n")
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <math.h>
  #include <float.h>
  #include <assert.h>
  static NSString *NSViewBoundsDidChangeNotification=@"BoundsChanged";
  @interface NSView : NSObject {
    NSRect _bounds, _frame; id _window; BOOL _postsNotificationOnBoundsChange;
  }
  - (id)initWithFrame:(NSRect)frame;
  - (NSRect)bounds;
  - (NSRect)frame;
  - (void)setBounds:(NSRect)bounds;
  - (void)setPostsBoundsChangedNotifications:(BOOL)value;
  - (void)scaleUnitSquareToSize:(NSSize)size;
  @end
  static void invalidateTransform(NSView *view) {}
  @implementation NSView
  - (id)initWithFrame:(NSRect)frame { if((self=[super init])) { _frame=frame; _bounds=frame; } return self; }
  - (NSRect)bounds { return _bounds; }
  - (NSRect)frame { return _frame; }
  - (void)setPostsBoundsChangedNotifications:(BOOL)value { _postsNotificationOnBoundsChange=value; }
  METHODS
  @end
OBJC
program.sub!('METHODS'){methods}
probe=File.read("#{root}/tests/nsview-unit-scaling.m").gsub(/^#import.*\n/,'')
if ARGV.include?('--overflow')
  probe.sub!('[[NSNotificationCenter defaultCenter] removeObserver: observer];', <<~'OBJC')
    @try { [view scaleUnitSquareToSize:NSMakeSize(DBL_MIN,1)]; }
    @catch (NSException *exception) {}
    assert(isfinite([view bounds].size.width));
    [[NSNotificationCenter defaultCenter] removeObserver: observer];
  OBJC
end
program+=probe
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('view-scaling') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'scaling probe failed' unless system(output,rlimit_core:0)
end
puts 'PASS: actual scaling/setBounds methods and original notification/argument probe (controlled view storage)'
