# Actual subclass implementation with controlled toolbar/menu collaborators.
# This tests state/ownership plumbing, not drawing or menu tracking.
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
root=File.expand_path('..',__dir__)
source=%w[AppKit/include/AppKit/NSMenuToolbarItem.h AppKit/NSMenuToolbarItem.m].map { |f| File.read("#{root}/#{f}").gsub(/^#import.*\n/,'') }.join("\n")
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  typedef NSString *NSToolbarItemIdentifier;
  static int menuDeaths;
  @class NSEvent, NSView;
  static id trackedMenu, trackedEvent, trackedView;
  @interface NSMenu : NSObject
  - (id)initWithTitle:(NSString*)title;
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view;
  @end
  @implementation NSMenu
  - (id)initWithTitle:(NSString*)title { return [super init]; }
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view {
    trackedMenu=menu; trackedEvent=event; trackedView=view;
  }
  - (void)dealloc { menuDeaths++; [super dealloc]; }
  @end
  @interface NSMenuItem : NSObject { @public NSMenu *submenu; }
  - (void)setSubmenu:(NSMenu*)value;
  @end
  @implementation NSMenuItem
  - (void)setSubmenu:(NSMenu*)value { [value retain]; [submenu release]; submenu=value; }
  - (void)dealloc { [submenu release]; [super dealloc]; }
  @end
  @interface NSToolbarItem : NSObject {
    @public NSMenuItem *_menuFormRepresentation; int redraws; SEL action;
  }
  - (id)initWithItemIdentifier:(NSString*)identifier;
  - (NSMenuItem*)menuFormRepresentation;
  - (void)_didChange;
  - (SEL)action;
  @end
  @implementation NSToolbarItem
  - (id)initWithItemIdentifier:(NSString*)identifier { return [super init]; }
  - (NSMenuItem*)menuFormRepresentation {
    if (!_menuFormRepresentation) _menuFormRepresentation=[NSMenuItem new];
    return _menuFormRepresentation;
  }
  - (void)_didChange { redraws++; }
  - (SEL)action { return action; }
  - (void)dealloc { [_menuFormRepresentation release]; [super dealloc]; }
  @end
  SOURCE
  int main(void) {
    @autoreleasepool {
      NSMenuToolbarItem *item=[[NSMenuToolbarItem alloc] initWithItemIdentifier:@"fonts"];
      assert([item menu]!=nil && [item showsIndicator]);
      assert(item->_menuFormRepresentation==nil);
      NSMenuItem *representation=[item menuFormRepresentation];
      assert(representation->submenu==[item menu]);
      NSMenu *replacement=[[NSMenu alloc] initWithTitle:@"new"];
      [item setMenu:replacement];
      assert(representation->submenu==replacement && item->redraws==1);
      [item setMenu:replacement]; assert(item->redraws==1);
      [replacement release];
      [item setShowsIndicator:NO]; assert(item->redraws==2 && ![item showsIndicator]);
      [item setShowsIndicator:NO]; assert(item->redraws==2);
      [item setMenu:nil]; assert([item menu]!=nil && representation->submenu==[item menu]);
      id event=[NSObject new], view=[NSObject new];
      assert([item _trackMenuWithEvent:event inView:view]);
      assert(trackedMenu==[item menu] && trackedEvent==event && trackedView==view);
      trackedMenu=nil; item->action=@selector(description);
      assert(![item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      [event release]; [view release];
      [item release];
    }
    assert(menuDeaths==3);
    puts("PASS: initial menu, replacement, self-assignment, representation sync, redraw, ownership after pool drain");
  }
OBJC
program.sub!('SOURCE') { source }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('menu-toolbar-state') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'test failed' unless system(output,rlimit_core:0)
end
