# Actual wheel methods with controlled hierarchy and document geometry.
require 'open3'
require 'tmpdir'
sdk=ARGV.fetch(0)
root=File.expand_path('..',__dir__)
view=File.read("#{root}/AppKit/NSView.m")[/^- \(void\) scrollWheel:.*?^\}/m]
scroll=File.read("#{root}/AppKit/NSScrollView.m")[/^- \(void\) scrollWheel:.*?^\}/m]
abort 'wheel methods missing' unless view && scroll
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static int forwarded, calls;
  @interface NSEvent : NSObject @end
  @implementation NSEvent
  - (CGFloat)deltaX { return 1; }
  - (CGFloat)deltaY { return 2; }
  @end
  @interface Responder : NSObject
  - (void)scrollWheel:(NSEvent*)event;
  @end
  @implementation Responder
  - (void)scrollWheel:(NSEvent*)event { forwarded++; }
  @end
  @class NSScrollView;
  @interface NSView : Responder {
    @public NSScrollView *outer; NSRect box, visible, requested; BOOL flipped; int requests;
  }
  - (NSScrollView*)enclosingScrollView;
  - (NSRect)bounds;
  - (NSRect)visibleRect;
  - (BOOL)isFlipped;
  - (BOOL)scrollRectToVisible:(NSRect)rect;
  @end
  @interface NSScrollView : NSView { @public NSView *document; }
  - (NSView*)documentView;
  - (CGFloat)horizontalLineScroll;
  - (CGFloat)verticalLineScroll;
  @end
  @implementation NSView
  - (NSScrollView*)enclosingScrollView { return outer; }
  - (NSRect)bounds { return box; }
  - (NSRect)visibleRect { return visible; }
  - (BOOL)isFlipped { return flipped; }
  - (BOOL)scrollRectToVisible:(NSRect)rect { requested=rect; requests++; return YES; }
  VIEW_METHOD
  @end
  @implementation NSScrollView
  - (NSView*)documentView { return document; }
  - (CGFloat)horizontalLineScroll { return 2; }
  - (CGFloat)verticalLineScroll { return 3; }
  SCROLL_METHOD
  @end
  @interface ObservedScroll : NSScrollView @end
  @implementation ObservedScroll
  - (void)scrollWheel:(NSEvent*)event { calls++; [super scrollWheel:event]; }
  @end
  int main(void) {
    @autoreleasepool {
      NSEvent *event=[NSEvent new]; NSView *doc=[NSView new], *child=[NSView new];
      ObservedScroll *scroll=[ObservedScroll new]; NSScrollView *outer=[NSScrollView new];
      NSView *outerDoc=[NSView new]; outer->document=outerDoc;
      scroll->document=doc; scroll->outer=outer; child->outer=scroll;
      doc->box=NSMakeRect(0,0,100,100); doc->visible=NSMakeRect(40,40,20,20);
      [scroll scrollWheel:event];
      assert(doc->requests==1 && outerDoc->requests==0 && calls==1);
      assert(doc->requested.origin.x==46 && doc->requested.origin.y==58);
      doc->flipped=YES; [child scrollWheel:event];
      assert(calls==2 && doc->requests==2 && doc->requested.origin.y==22);
      doc->flipped=NO; doc->visible=NSMakeRect(90,90,20,20);
      [scroll scrollWheel:event]; assert(doc->requested.origin.x==80 && doc->requested.origin.y==80);
      scroll->document=nil; [scroll scrollWheel:event]; assert(outerDoc->requests==1);
      scroll->outer=nil; [scroll scrollWheel:event]; assert(forwarded==1);
      child->outer=nil; [child scrollWheel:event]; assert(forwarded==2);
      child->outer=(id)child; [child scrollWheel:event]; assert(forwarded==3);
      [outerDoc release]; [outer release]; [scroll release]; [child release]; [doc release]; [event release];
    }
    puts("PASS: direct/child/nested routing, subclass override, missing documents, flipped axes, horizontal movement and edge clamp");
  }
OBJC
program.sub!('VIEW_METHOD'){view}; program.sub!('SCROLL_METHOD'){scroll}
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('scroll-routing') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'routing test failed' unless system(output,rlimit_core:0)
end
