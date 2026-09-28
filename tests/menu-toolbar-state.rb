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
  static void (*duringPeek)(void);
  static void (*duringPopup)(void);
  enum { NSLeftMouseUpMask=4, NSLeftMouseDraggedMask=8 };
  #define NSEventTrackingRunLoopMode @"tracking"
  @interface ProbeApplication : NSObject { @public id pending; BOOL dequeued; NSUInteger mask; NSString *mode; }
  - (id)nextEventMatchingMask:(NSUInteger)value untilDate:(NSDate*)date inMode:(NSString*)runMode dequeue:(BOOL)remove;
  @end
  @implementation ProbeApplication
  - (id)nextEventMatchingMask:(NSUInteger)value untilDate:(NSDate*)date inMode:(NSString*)runMode dequeue:(BOOL)remove {
    assert([date timeIntervalSinceNow]>0);
    mask=value; mode=runMode; dequeued=remove;
    if (duringPeek) duringPeek();
    return pending;
  }
  @end
  static ProbeApplication *NSApp;
  @interface NSMenu : NSObject
  - (id)initWithTitle:(NSString*)title;
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view;
  @end
  @implementation NSMenu
  - (id)initWithTitle:(NSString*)title { return [super init]; }
  + (void)popUpContextMenu:(id)menu withEvent:(id)event forView:(id)view {
    trackedMenu=menu; trackedEvent=event; trackedView=view;
    if (duringPopup) duringPopup();
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
    @public NSMenuItem *_menuFormRepresentation; int redraws; SEL action; BOOL disabled;
  }
  - (id)initWithItemIdentifier:(NSString*)identifier;
  - (NSMenuItem*)menuFormRepresentation;
  - (void)_didChange;
  - (SEL)action;
  - (BOOL)isEnabled;
  @end
  @implementation NSToolbarItem
  - (id)initWithItemIdentifier:(NSString*)identifier { return [super init]; }
  - (NSMenuItem*)menuFormRepresentation {
    if (!_menuFormRepresentation) _menuFormRepresentation=[NSMenuItem new];
    return _menuFormRepresentation;
  }
  - (void)_didChange { redraws++; }
  - (SEL)action { return action; }
  - (BOOL)isEnabled { return !disabled; }
  - (void)dealloc { [_menuFormRepresentation release]; [super dealloc]; }
  @end
  SOURCE
  static NSMenuToolbarItem *activeItem;
  static void reenterAndDisable(void) {
    assert([activeItem _trackMenuWithEvent:nil inView:nil]);
    assert(trackedMenu==nil);
    activeItem->disabled=YES;
  }
  static void throwDuringCallback(void) {
    [NSException raise:@"ProbeTrackingException" format:@"controlled callback failure"];
  }
  static void checkExceptionCleanup(NSMenuToolbarItem *item, id event, id view, BOOL popup) {
    // Read the atomic getter before measuring, since it may autorelease a retain.
    NSMenu *menu=[item menu];
    NSUInteger itemCount=[item retainCount], eventCount=[event retainCount];
    NSUInteger viewCount=[view retainCount], menuCount=[menu retainCount];
    duringPeek=popup ? NULL : throwDuringCallback;
    duringPopup=popup ? throwDuringCallback : NULL;
    BOOL caught=NO;
    @try {
      [item _trackMenuWithEvent:event inView:view];
    } @catch (NSException *exception) {
      assert([[exception name] isEqual:@"ProbeTrackingException"]);
      caught=YES;
    }
    duringPeek=NULL; duringPopup=NULL;
    assert(caught);
    assert([item retainCount]==itemCount && [event retainCount]==eventCount);
    assert([view retainCount]==viewCount && [menu retainCount]==menuCount);
    // An exception must not leave the transient tracking guard latched.
    trackedMenu=nil;
    assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==menu);
  }
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
      NSApp=[ProbeApplication new]; NSApp->pending=event;
      assert(![item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      assert(!NSApp->dequeued && NSApp->mask==(NSLeftMouseUpMask|NSLeftMouseDraggedMask));
      assert([NSApp->mode isEqual:NSEventTrackingRunLoopMode]);
      NSApp->pending=nil;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==[item menu]);
      trackedMenu=nil; activeItem=item; duringPeek=reenterAndDisable;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==nil);
      duringPeek=NULL; item->disabled=NO;
      assert([item _trackMenuWithEvent:event inView:view] && trackedMenu==[item menu]);
      checkExceptionCleanup(item,event,view,NO);
      checkExceptionCleanup(item,event,view,YES);
      [NSApp release]; NSApp=nil;
      [event release]; [view release];
      [item release];
    }
    assert(menuDeaths==3);
    puts("PASS: menu state, representation sync, quick/held gestures, reentry, disabled state, exception cleanup, ownership after pool drain");
  }
OBJC
program.sub!('SOURCE') { source }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('menu-toolbar-state') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'test failed' unless system(output,rlimit_core:0)
end
