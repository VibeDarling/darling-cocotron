# Actual item accessors with controlled view/controller/tab adapters.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
root=ARGV[1] || File.expand_path('..',__dir__)
source=File.read(File.join(root,'AppKit/NSTabViewItem.m'))
methods=[source[/^- \(void\) setViewController:.*?^\}/m],source[/^- view \{.*?^\}/m],source[/^- \(void\) setView:.*?^\}/m]]
methods += [source[/^\+ \(instancetype\) tabViewItemWithViewController:.*?^\}/m],
            source[/^- initWithIdentifier:.*?^\}/m], source[/^- \(void\) dealloc.*?^\}/m]]
abort 'missing method' if methods.any?(&:nil?)
tab_source=File.read(File.join(root,'AppKit/NSTabView.m'))
tab_methods=%w[selectTabViewItem _itemViewDidChange addTabViewItem].map do |name|
  tab_source[/^- \(void\) #{name}:.*?^\}/m] or abort "missing #{name}"
end
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static unsigned controllerDeaths;
  enum { NSBackgroundTab=1 };
  @interface NSColor : NSObject @end
  @implementation NSColor
  + (id)controlColor { return [[[self alloc] init] autorelease]; }
  @end
  @interface NSObject (ProbeCallbacks)
  - (void)setViewController:(id)value;
  - (void)_itemViewDidChange:(id)item;
  - (BOOL)tabView:(id)tab shouldSelectTabViewItem:(id)item;
  - (void)tabView:(id)tab willSelectTabViewItem:(id)item;
  - (void)tabView:(id)tab didSelectTabViewItem:(id)item;
  - (void)tabViewDidChangeNumberOfTabViewItems:(id)tab;
  - (void)setNeedsDisplay:(BOOL)value;
  - (void)makeFirstResponder:(id)view;
  @end
  @interface NSView : NSObject { @public unsigned removals; } @end
  @implementation NSView
  - (void)removeFromSuperview { ++removals; }
  - (void)setFrame:(NSRect)frame {}
  @end
  @interface NSViewController : NSObject { @public unsigned loads; NSView *content; id target,replacement; BOOL replaceDuringLoad,reenter,throwOnce; } @end
  @implementation NSViewController
  - (void)dealloc { ++controllerDeaths; [super dealloc]; }
  - (id)view {
    ++loads;
    if(reenter) { reenter=NO; assert([target view]==nil); }
    if(throwOnce) { throwOnce=NO; [NSException raise:@"ProbeLoad" format:@"expected"]; }
    if(replaceDuringLoad) { replaceDuringLoad=NO; [target setViewController:replacement]; }
    return content;
  }
  @end
  @interface Item : NSObject { @public NSViewController *_viewController; NSView *_view; id _initialFirstResponder,_tabView,_identifier,_label,_color; int _state; BOOL _loadingControllerView; }
  - (id)initWithIdentifier:(id)value;
  @end
  @compatibility_alias NSTabViewItem Item;
  @implementation Item
  METHODS
  - (id)initialFirstResponder { return _initialFirstResponder; }
  - (void)setTabView:(id)tab { _tabView=tab; }
  @end
  @interface Tab : NSObject { @public Item *_selectedItem; id _delegate; NSMutableArray *_items; NSView *attached; } @end
  @implementation Tab
  TAB_METHODS
  - (id)init { if((self=[super init])) _items=[NSMutableArray new]; return self; }
  - (void)dealloc { [_items release]; [super dealloc]; }
  - (id)window { return nil; }
  - (id)superview { return nil; }
  - (NSRect)contentRect { return NSZeroRect; }
  - (void)addSubview:(NSView *)view { attached=view; }
  - (void)setNeedsDisplay:(BOOL)value {}
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
      tab->_selectedItem=item;
      [item setViewController:second];
      assert(item->_view==b && second->loads==1 && item->_initialFirstResponder==b);
      [item setViewController:nil]; assert(item->_view==nil && item->_initialFirstResponder==nil);
      second->content=nil;
      [item setViewController:second]; assert(item->_view==nil); // No recursive nil-view notification.
      item->_tabView=nil;
      second->content=b;
      first->target=item; first->replacement=second; first->replaceDuringLoad=YES;
      [item setViewController:first];
      assert([item view]==b); // Service the replacement, never install the retired result.
      assert(item->_viewController==second && [item view]==b);
      first->reenter=YES; first->throwOnce=YES;
      [item setViewController:first];
      BOOL caught=NO;
      @try { [item view]; }
      @catch(NSException *e) { assert([[e name] isEqual:@"ProbeLoad"]); caught=YES; }
      assert(caught && !item->_loadingControllerView && item->_view==nil);
      assert([item view]==a);
      [item release]; [tab release];
      first->loads=second->loads=0;
      Item *one=[Item new], *two=[Item new]; Tab *tabs=[Tab new];
      [one setViewController:first]; [two setViewController:second];
      assert(first->loads==0 && second->loads==0);
      [tabs addTabViewItem:one]; [tabs addTabViewItem:two];
      assert(first->loads==1 && second->loads==0 && tabs->attached==a);
      [tabs selectTabViewItem:two];
      assert(first->loads==1 && second->loads==1 && tabs->attached==b);
      [tabs selectTabViewItem:one];
      assert(first->loads==1 && second->loads==1 && tabs->attached==a);
      first->target=two; first->replacement=second; first->replaceDuringLoad=YES;
      [two setViewController:first];
      [tabs selectTabViewItem:two];
      assert(two->_viewController==second && two->_view==b && tabs->attached==b);
      one->_tabView=two->_tabView=nil;
      [one release]; [two release]; [tabs release];
      [first release]; [second release]; [a release]; [b release];
      unsigned deaths=controllerDeaths;
      Item *held;
      @autoreleasepool {
        NSViewController *owned=[NSViewController new];
        held=[[Item tabViewItemWithViewController:owned] retain];
        assert(owned->loads==0 && held->_viewController==owned);
        [owned release]; assert(controllerDeaths==deaths);
      }
      assert(controllerDeaths==deaths); // Factory autorelease did not consume our retain.
      [held release]; assert(controllerDeaths==deaths+1);
      puts("PASS: deferred/cached load, replacement, nil, stale-result rejection, recursive load and exception recovery");
    }
  }
OBJC
program.sub!('METHODS'){methods.join("\n")}
program.sub!('TAB_METHODS'){tab_methods.join("\n")}
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('tab-item-controller') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
