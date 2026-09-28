# Actual item accessors with controlled view/controller/tab adapters.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
root=ARGV[1] || File.expand_path('..',__dir__)
source=File.read(File.join(root,'AppKit/NSTabViewItem.m'))
methods=[source[/^- \(void\) setViewController:.*?^\}/m],source[/^- view \{.*?^\}/m],source[/^- \(void\) setView:.*?^\}/m]]
abort 'missing method' if methods.any?(&:nil?)
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface NSView : NSObject { @public unsigned removals; } @end
  @implementation NSView
  - (void)removeFromSuperview { ++removals; }
  @end
  @interface NSViewController : NSObject { @public unsigned loads; NSView *content; } @end
  @implementation NSViewController
  - (id)view { ++loads; return content; }
  @end
  @interface Item : NSObject { @public NSViewController *_viewController; NSView *_view; id _initialFirstResponder,_tabView; }
  @end
  @implementation Item
  METHODS
  - (void)dealloc { [_view release]; [_viewController release]; [super dealloc]; }
  @end
  @interface Tab : NSObject { @public Item *selected; unsigned changes; } @end
  @implementation Tab
  - (void)_itemViewDidChange:(Item *)item { ++changes; if(item==selected) [item view]; }
  @end
  int main(void) {
    @autoreleasepool {
      NSView *a=[NSView new], *b=[NSView new];
      NSViewController *first=[NSViewController new], *second=[NSViewController new];
      first->content=a; second->content=b;
      Item *item=[Item new]; Tab *tab=[Tab new]; item->_tabView=tab;
      [item setViewController:first]; assert(first->loads==0 && item->_view==nil);
      assert([item view]==a && first->loads==1 && item->_initialFirstResponder==a);
      assert([item view]==a && first->loads==1);
      [item setViewController:first]; assert(first->loads==1);
      tab->selected=item;
      [item setViewController:second];
      assert(item->_view==b && second->loads==1 && item->_initialFirstResponder==b);
      [item setViewController:nil]; assert(item->_view==nil && item->_initialFirstResponder==nil);
      second->content=nil;
      [item setViewController:second]; assert(item->_view==nil); // No recursive nil-view notification.
      item->_tabView=nil; [item release]; [tab release];
      [first release]; [second release]; [a release]; [b release];
      puts("PASS: deferred load, cached view, self assignment, selected replacement, nil controller/view");
    }
  }
OBJC
program.sub!('METHODS'){methods.join("\n")}
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('tab-item-controller') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
