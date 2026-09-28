# Actual window getter with controlled lifecycle callbacks, not NIB decoding.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
source=File.read(File.expand_path('../AppKit/NSWindowController.m',__dir__))
method=source[/- \(NSWindow \*\) window \{.*?^\}/m] or abort 'getter missing'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  @interface NSWindow : NSObject @end
  @implementation NSWindow @end
  @interface Controller : NSObject {
  @public NSWindow *_window; BOOL _loadingWindowLifecycle,_loadingWindowNib;
      NSString *_nibPath; id _document; int will,load,did,docWill,docDid; BOOL throws;
  }
  - (NSWindow *)window;
  - (NSString *)windowNibName;
  - (void)windowWillLoad;
  - (void)loadWindow;
  - (void)windowDidLoad;
  - (void)windowControllerWillLoadNib:(id)c;
  - (void)windowControllerDidLoadNib:(id)c;
  @end
  @implementation Controller
  - (NSString *)windowNibName { return @"fixture"; }
  - (void)windowWillLoad { assert(++will<10); assert([self window]==nil); }
  - (void)windowControllerWillLoadNib:(id)c { docWill++; assert([self window]==nil); }
  - (void)loadWindow {
      load++; assert([self window]==nil);
      if (throws) [NSException raise:@"Test" format:@"intentional failure"];
      _window=[NSWindow new];
  }
  - (void)windowDidLoad { did++; assert([self window]==_window); }
  - (void)windowControllerDidLoadNib:(id)c { docDid++; assert([self window]==_window); }
  - (void)dealloc { [_window release]; [super dealloc]; }
  ACTUAL_GETTER
  @end
  int main(void) {
      @autoreleasepool {
          Controller *c=[Controller new]; c->_document=c;
          c->throws=YES;
          @try { [c window]; assert(0); } @catch (NSException *e) { assert([[e name] isEqual:@"Test"]); }
          assert(!c->_loadingWindowLifecycle && c->will==1 && c->load==1 && c->did==0 && c->docWill==1);
          c->throws=NO;
          assert([c window]!=nil);
          assert(c->will==2 && c->load==2 && c->did==1 && c->docWill==2 && c->docDid==1);
          assert([c window]==c->_window && c->load==2 && !c->_loadingWindowLifecycle);
          [c release];
          c=[Controller new]; c->_loadingWindowNib=YES;
          assert([c window]==nil && c->will==0 && c->load==0);
          [c release];
          puts("Actual getter callback reentry, document callbacks, exception retry and NIB guard tests passed");
      }
  }
OBJC
program=program.sub('ACTUAL_GETTER') { method }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('window-getter-host') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
