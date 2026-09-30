# Actual menu getter with a controlled mutable item collection, using GNUstep.
# Usage: ruby tests/menu-item-array.rb GNUSTEP_ROOT [BASELINE_REF]
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
repo=File.expand_path('..',__dir__)
source=File.read("#{repo}/AppKit/NSMenu.subproj/NSMenu.m")
if ARGV[1]
  source,status=Open3.capture2('git','-C',repo,'show',"#{ARGV[1]}:AppKit/NSMenu.subproj/NSMenu.m")
  abort 'baseline unavailable' unless status.success?
end
getter=source[/^- \(NSArray \*\) itemArray.*?^\}/m] or abort 'missing getter'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface Menu : NSObject { @public NSMutableArray *_itemArray; } @end
  @implementation Menu
  GETTER
  - (void)dealloc { [_itemArray release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      Menu *menu=[Menu new];
      NSObject *first=[NSObject new], *second=[NSObject new];
      menu->_itemArray=[[NSMutableArray alloc] initWithObjects:first,second,nil];
      NSArray *snapshot=[[menu itemArray] retain];
      NSUInteger visited=0;
      for (id item in snapshot) {
        assert(item==first || item==second);
        [menu->_itemArray removeObjectIdenticalTo:item];
        visited++;
      }
      assert(visited==2 && [menu->_itemArray count]==0 && [snapshot count]==2);
      BOOL rejected=NO;
      @try { [(NSMutableArray*)snapshot removeAllObjects]; }
      @catch (NSException *exception) { rejected=YES; }
      assert(rejected && [snapshot count]==2);
      [menu->_itemArray addObject:first];
      assert([[menu itemArray] count]==1 && [snapshot count]==2);
      [menu release];
      assert([snapshot objectAtIndex:0]==first && [snapshot objectAtIndex:1]==second);
      [snapshot release]; [first release]; [second release];
      puts("PASS: snapshot membership, mutation during iteration, immutable result, retained items");
    }
  }
OBJC
program.sub!('GETTER') { getter }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
objc_runtime,status=Open3.capture2('gcc','-print-file-name=libobjc.so'); abort unless status.success?
objc_runtime=objc_runtime.strip
abort 'GNU Objective-C runtime unavailable' unless File.file?(objc_runtime)
Dir.mktmpdir('menu-snapshot') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base',objc_runtime,'-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
