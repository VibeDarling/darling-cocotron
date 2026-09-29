# Actual view/application dispatch methods with controlled hierarchy/window callbacks.
# Usage: ruby tests/constraint-scheduling.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
view=File.read(File.join(root,'AppKit/NSView.m'))
app=File.read(File.join(root,'AppKit/NSApplication.m'))
def extract(source,name)
  source[/^- \(void\) #{Regexp.escape(name)} \{.*?^\}/m] or abort "missing #{name}"
end
vm=['setNeedsUpdateConstraints: (BOOL) flag','updateConstraintsForSubtreeIfNeeded',
    '_layoutSubtreeAfterUpdatingConstraints','layoutSubtreeIfNeeded'].map{|n|extract(view,n)}.join("\n")
am=extract(app,'_displayAllWindowsIfNeeded')
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @class NSWindow;
  static NSMutableArray *events,*windows;
  static id NSApp;
  @interface NSView : NSObject {
  @public NSMutableArray *_subviews; BOOL _needsUpdateConstraints,_needsLayout;
    NSView *parent; NSWindow *window; NSString *name; BOOL closeWindow;
  }
  - (void)setNeedsUpdateConstraints:(BOOL)flag;
  - (void)updateConstraintsForSubtreeIfNeeded;
  - (void)layoutSubtreeIfNeeded;
  - (void)_layoutSubtreeAfterUpdatingConstraints;
  @end
  @interface NSWindow : NSObject {
  @public NSView *root; BOOL visible,mini,dirty; unsigned displays;
  }
  - (void)setViewsNeedDisplay:(BOOL)value;
  @end
  @implementation NSWindow
  - (BOOL)isVisible { return visible; }
  - (BOOL)isMiniaturized { return mini; }
  - (id)_backgroundView { return root; }
  - (void)setViewsNeedDisplay:(BOOL)value { dirty=value; }
  - (void)displayIfNeeded { if(visible && !mini && dirty) { ++displays; dirty=NO; [events addObject:@"display"]; } }
  @end
  @implementation NSView
  VIEW_METHODS
  - (id)init { if((self=[super init])) _subviews=[NSMutableArray new]; return self; }
  - (id)window { return window; }
  - (id)superview { return parent; }
  - (void)updateConstraints {
    [events addObject:[@"update:" stringByAppendingString:name]];
    if(closeWindow) { window->visible=NO; [windows removeObjectIdenticalTo:window]; }
    _needsUpdateConstraints=NO;
  }
  - (void)layout { [events addObject:[@"layout:" stringByAppendingString:name]]; _needsLayout=NO; }
  - (void)dealloc { [_subviews release]; [super dealloc]; }
  @end
  @interface App : NSObject @end
  @implementation App
  - (id)windows { return windows; }
  APP_METHOD
  @end
  int main(void) {
    @autoreleasepool {
      events=[NSMutableArray new]; windows=[NSMutableArray new]; NSApp=[App new];
      NSWindow *w=[NSWindow new]; w->visible=YES;
      NSView *r=[NSView new],*c=[NSView new]; r->name=@"root"; c->name=@"child";
      w->root=r; r->window=w; c->window=w; c->parent=r; [r->_subviews addObject:c];
      [windows addObject:w];
      [r setNeedsUpdateConstraints:YES]; [c setNeedsUpdateConstraints:YES];
      [c setNeedsUpdateConstraints:YES]; assert(w->dirty);
      [r layoutSubtreeIfNeeded];
      assert(([events isEqual:@[@"update:root",@"update:child",@"layout:root",@"layout:child"]]));
      [events removeAllObjects]; [r layoutSubtreeIfNeeded]; assert([events count]==0);
      [c setNeedsUpdateConstraints:YES]; [NSApp _displayAllWindowsIfNeeded];
      assert(([events isEqual:@[@"update:child",@"layout:child",@"display"]]));
      [events removeAllObjects]; w->mini=YES; [c setNeedsUpdateConstraints:YES];
      [NSApp _displayAllWindowsIfNeeded]; assert([events count]==0 && c->_needsUpdateConstraints);
      w->mini=NO; w->visible=NO; [NSApp _displayAllWindowsIfNeeded]; assert([events count]==0);
      w->visible=YES; [NSApp _displayAllWindowsIfNeeded]; assert(!c->_needsUpdateConstraints);
      // Closing a window from a callback mutates the source list, not its snapshot.
      [events removeAllObjects]; r->closeWindow=YES; [r setNeedsUpdateConstraints:YES];
      [NSApp _displayAllWindowsIfNeeded]; assert([windows count]==0 && !w->visible);
      assert(![events containsObject:@"display"]);
      [r release]; [c release]; [w release]; [NSApp release]; [events release]; [windows release];
      puts("PASS: update-before-layout, coalescing, explicit/automatic dispatch, hidden/minimized deferral and callback window removal");
    }
  }
OBJC
program=program.sub('VIEW_METHODS'){vm}.sub('APP_METHOD'){am}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('constraint-scheduling') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'scheduling probe failed' unless system(output,rlimit_core:0)
end
