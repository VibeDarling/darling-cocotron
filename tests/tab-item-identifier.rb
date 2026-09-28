# Actual identifier accessors and tab lookup/selection entry point; host Foundation.
# Usage: ruby tests/tab-item-identifier.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
item=File.read(File.join(root,'AppKit/NSTabViewItem.m'))
tab=File.read(File.join(root,'AppKit/NSTabView.m'))
getter=item[/^- identifier \{.*?^\}/m] or abort 'missing getter'
setter=item[/^- \(void\) setIdentifier:.*?^\}/m] || ''
lookup=tab[/^- \(NSInteger\) indexOfTabViewItemWithIdentifier:.*?^\}/m] or abort 'missing lookup'
select=tab[/^- \(void\) selectTabViewItemWithIdentifier:.*?^\}/m] or abort 'missing selection'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static unsigned deaths;
  @interface Tracked : NSObject @end
  @implementation Tracked
  - (void)dealloc { ++deaths; [super dealloc]; }
  @end
  @interface NSTabViewItem : NSObject { id _identifier; }
  - (id)identifier;
  - (void)setIdentifier:(id)identifier;
  @end
  @implementation NSTabViewItem
  ITEM_METHODS
  - (void)dealloc { [_identifier release]; [super dealloc]; }
  @end
  @interface Tab : NSObject { @public NSArray *_items; NSInteger selected; }
  @end
  @implementation Tab
  TAB_METHODS
  - (void)selectTabViewItemAtIndex:(NSInteger)index { selected=index; }
  - (void)dealloc { [_items release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      NSTabViewItem *a=[NSTabViewItem new], *b=[NSTabViewItem new];
      assert([a respondsToSelector:@selector(setIdentifier:)]);
      assert([a identifier]==nil);
      Tracked *value=[Tracked new]; [a setIdentifier:value]; [value release];
      assert(deaths==0); [a setIdentifier:[a identifier]]; assert(deaths==0);
      [a setIdentifier:nil]; assert(deaths==1 && [a identifier]==nil);
      NSMutableString *name=[NSMutableString stringWithString:@"old"];
      [a setIdentifier:name]; [name appendString:@"-mutable"];
      assert([a identifier]==name); // retain, not copy
      [b setIdentifier:@"second"];
      Tab *tab=[Tab new]; tab->_items=[[NSArray alloc] initWithObjects:a,b,nil];
      assert([tab indexOfTabViewItemWithIdentifier:@"old-mutable"]==0);
      [a setIdentifier:@"renamed"];
      assert([tab indexOfTabViewItemWithIdentifier:@"old-mutable"]==NSNotFound);
      assert([tab indexOfTabViewItemWithIdentifier:@"renamed"]==0);
      [tab selectTabViewItemWithIdentifier:@"second"]; assert(tab->selected==1);
      [tab selectTabViewItemWithIdentifier:@"renamed"]; assert(tab->selected==0);
      [a setIdentifier:nil]; assert([tab indexOfTabViewItemWithIdentifier:@"renamed"]==NSNotFound);
      value=[Tracked new]; [b setIdentifier:value]; [value release];
      [tab release]; [a release]; [b release]; assert(deaths==2);
      puts("PASS: retention, self-assignment, replacement/nil, mutable identifiers, lookup and selection dispatch");
    }
  }
OBJC
program=program.sub('ITEM_METHODS'){getter+"\n"+setter}.sub('TAB_METHODS'){lookup+"\n"+select}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('tab-identifier') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'identifier regression failed' unless system(output,rlimit_core:0)
end
