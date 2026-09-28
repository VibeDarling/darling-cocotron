# Actual selection/count methods with controlled segment items; no UI event tracking.
# Usage: ruby tests/segmented-selection.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk, root = ARGV
root ||= File.expand_path('..', __dir__)
source = File.read(File.join(root,'AppKit/NSSegmentedControl/NSSegmentedCell.m'))
methods = [source[/^- \(void\) setSelectedSegment:.*?^\}/m],
           source[/^- \(void\) setSegmentCount:.*?^\}/m],
           source[/^- \(NSInteger\) selectedSegment.*?^\}/m]]
abort 'method missing' if methods.any?(&:nil?)
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface NSSegmentItem : NSObject { BOOL selected; }
  - (void)setSelected:(BOOL)value;
  - (BOOL)isSelected;
  @end
  @implementation NSSegmentItem
  - (void)setSelected:(BOOL)value { selected=value; }
  - (BOOL)isSelected { return selected; }
  @end
  @interface Cell : NSObject {
  @public NSMutableArray *_segments; NSInteger _selectedSegment;
  }
  @end
  @implementation Cell
  METHODS
  - (id)init { if((self=[super init])) { _segments=[NSMutableArray new]; _selectedSegment=NSNotFound; } return self; }
  - (void)_recomputeSegmentWidths {}
  - (void)dealloc { [_segments release]; [super dealloc]; }
  @end
  static void check(Cell *cell, NSInteger selected) {
    assert([cell selectedSegment] == selected);
    for(NSUInteger i=0;i<[cell->_segments count];++i)
      assert([[cell->_segments objectAtIndex:i] isSelected] == ((NSInteger)i == selected));
  }
  int main(void) {
    @autoreleasepool {
      Cell *cell=[Cell new];
      [cell setSelectedSegment:-1]; check(cell,-1);
      [cell setSegmentCount:2]; check(cell,-1);
      [cell setSelectedSegment:0]; check(cell,0);
      [cell setSelectedSegment:1]; check(cell,1);
      [cell setSelectedSegment:1]; check(cell,1);
      NSInteger invalid[]={-2,2,5,NSIntegerMin,NSIntegerMax};
      for(unsigned i=0;i<5;++i) {
        BOOL raised=NO;
        @try { [cell setSelectedSegment:invalid[i]]; }
        @catch(NSException *e) { assert([[e name] isEqual:NSRangeException]); raised=YES; }
        assert(raised); check(cell,1);
      }
      [cell setSegmentCount:6]; check(cell,1);
      [cell setSelectedSegment:-1]; check(cell,-1);
      [cell setSegmentCount:0]; check(cell,-1);
      BOOL raised=NO;
      @try { [cell setSelectedSegment:0]; }
      @catch(NSException *e) { assert([[e name] isEqual:NSRangeException]); raised=YES; }
      assert(raised); check(cell,-1);
      [cell setSegmentCount:3]; check(cell,-1);
      [cell release];
      puts("PASS: deselection, valid replacement, invalid-index atomicity, empty cells and growth");
    }
  }
OBJC
program.sub!('METHODS') { methods.join("\n") }
gcc, status = Open3.capture2('gcc','-print-file-name=include')
abort 'headers unavailable' unless status.success?
Dir.mktmpdir('segmented-selection') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
