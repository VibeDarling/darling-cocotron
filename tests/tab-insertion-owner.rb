# Actual insertion and selection methods, host Foundation and controlled delegates.
# Usage: ruby tests/tab-insertion-owner.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
source=File.read(File.join(root,'AppKit/NSTabView.m'))
methods=['addTabViewItem: (NSTabViewItem *) item','insertTabViewItem: (NSTabViewItem *) item atIndex: (NSInteger) index',
         'selectTabViewItem: (NSTabViewItem *) item'].map do |name|
  source[/^- \(void\) #{Regexp.escape(name)} \{.*?^\}/m] or abort "missing #{name}"
end.join("\n")
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface NSObject (FixtureDrawing)
  - (void)removeFromSuperview;
  - (void)setFrame:(NSRect)frame;
  - (void)makeFirstResponder:(id)view;
  @end
  @interface NSTabViewItem : NSObject { @public id owner; }
  @end
  @implementation NSTabViewItem
  - (void)setTabView:(id)view { owner=view; }
  - (id)view { return nil; }
  - (id)initialFirstResponder { return nil; }
  @end
  @interface Delegate : NSObject { @public BOOL veto; unsigned should,will,did,changed; }
  - (BOOL)tabView:(id)tab shouldSelectTabViewItem:(NSTabViewItem *)item;
  - (void)tabView:(id)tab willSelectTabViewItem:(NSTabViewItem *)item;
  - (void)tabView:(id)tab didSelectTabViewItem:(NSTabViewItem *)item;
  - (void)tabViewDidChangeNumberOfTabViewItems:(id)tab;
  @end
  @implementation Delegate
  - (BOOL)tabView:(id)tab shouldSelectTabViewItem:(NSTabViewItem *)item { assert(item->owner==tab); ++should; return !veto; }
  - (void)tabView:(id)tab willSelectTabViewItem:(NSTabViewItem *)item { assert(item->owner==tab); ++will; }
  - (void)tabView:(id)tab didSelectTabViewItem:(NSTabViewItem *)item { assert(item->owner==tab); ++did; }
  - (void)tabViewDidChangeNumberOfTabViewItems:(id)tab { ++changed; }
  @end
  @interface Tab : NSObject {
  @public NSMutableArray *_items; NSTabViewItem *_selectedItem; Delegate *_delegate;
  }
  @end
  @implementation Tab
  ACTUAL_METHODS
  - (id)init { if((self=[super init])) _items=[NSMutableArray new]; return self; }
  - (id)window { return nil; }
  - (id)superview { return nil; }
  - (NSRect)contentRect { return NSZeroRect; }
  - (void)addSubview:(id)view {}
  - (void)setNeedsDisplay:(BOOL)value {}
  - (void)dealloc { [_items release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      for(unsigned insertion=0; insertion<2; ++insertion) {
        for(unsigned veto=0; veto<2; ++veto) {
          Tab *tab=[Tab new]; Delegate *d=[Delegate new]; d->veto=veto; tab->_delegate=d;
          NSTabViewItem *a=[NSTabViewItem new],*b=[NSTabViewItem new];
          if(insertion) [tab insertTabViewItem:a atIndex:0]; else [tab addTabViewItem:a];
          assert(a->owner==tab && d->should==1 && d->changed==1);
          assert(d->will==!veto && d->did==!veto);
          assert(tab->_selectedItem==(veto?nil:a));
          if(!veto) {
            if(insertion) [tab insertTabViewItem:b atIndex:0]; else [tab addTabViewItem:b];
            assert(b->owner==tab && tab->_selectedItem==a);
            assert(d->should==1 && d->changed==2);
          }
          [a release]; [b release]; [tab release]; [d release];
        }
      }
      puts("PASS: add/insert delegate ownership, veto and preserved nonempty selection");
    }
  }
OBJC
program=program.sub('ACTUAL_METHODS'){methods}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('tab-owner') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'ownership regression failed' unless system(output,rlimit_core:0)
end
