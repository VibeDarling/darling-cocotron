# Execute actual base loadWindow with a controlled NIB loader and ownership model.
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
source=File.read(File.expand_path('../AppKit/NSWindowController.m',__dir__))
method=source[/- \(void\) loadWindow \{.*?^\}/m] or abort 'loader missing'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static NSString *NSNibOwner=@"owner", *NSNibTopLevelObjects=@"objects";
  static int calls,alive,destroyed,mode;
  static BOOL reenter;
  @class Controller;
  static Controller *controller;
  @interface Window : NSObject
  - (NSPoint)cascadeTopLeftFromPoint:(NSPoint)p;
  @end
  @implementation Window
  - (NSPoint)cascadeTopLeftFromPoint:(NSPoint)p { return p; }
  @end
  @interface Controller : NSObject {
  @public BOOL _loadingWindowNib,_shouldCascadeWindows; Window *_window; id _owner; NSMutableArray *_topLevelObjects;
  }
  - (void)loadWindow;
  - (BOOL)isWindowLoaded;
  - (NSString *)windowNibPath;
  - (void)synchronizeWindowTitleWithDocumentName;
  @end
  @interface Sentinel : NSObject @end
  @implementation Sentinel
  - (id)init { if ((self=[super init])) alive++; return self; }
  - (void)dealloc {
      alive--; destroyed++;
      if (reenter) { assert(controller->_topLevelObjects==nil); [controller loadWindow]; }
      [super dealloc];
  }
  @end
  @interface ProbeBundle : NSObject
  + (BOOL)loadNibFile:(id)path externalNameTable:(id)table withZone:(void *)zone;
  @end
  @implementation ProbeBundle
  + (BOOL)loadNibFile:(id)path externalNameTable:(id)table withZone:(void *)zone {
      calls++; assert(calls<10);
      [controller loadWindow]; // direct recursion must be suppressed
      Sentinel *object=[Sentinel new];
      [[table objectForKey:NSNibTopLevelObjects] addObject:object];
      // Keep +1 to model the extra ownership transferred by the real NIB path.
      if (mode==1) [NSException raise:@"Test" format:@"intentional NIB failure"];
      if (mode==2) controller->_window=[Window new];
      return mode==2;
  }
  @end
  #define NSBundle ProbeBundle
  @implementation Controller
  - (BOOL)isWindowLoaded { return _window!=nil; }
  - (NSString *)windowNibPath { return @"fixture.nib"; }
  - (void)synchronizeWindowTitleWithDocumentName {}
  - (void)dealloc {
      [_topLevelObjects makeObjectsPerformSelector:@selector(release)];
      [_topLevelObjects release]; [_window release]; [super dealloc];
  }
  ACTUAL_METHOD
  @end
  int main(void) {
      @autoreleasepool {
          controller=[Controller new]; controller->_owner=controller; reenter=YES;
          @autoreleasepool { [controller loadWindow]; }
          assert(calls==1 && alive==1 && destroyed==0 && !controller->_loadingWindowNib);
          mode=1;
          @autoreleasepool {
              @try { [controller loadWindow]; assert(0); }
              @catch(NSException *e) { assert([[e name] isEqual:@"Test"]); }
          }
          assert(calls==2 && alive==1 && destroyed==1 && !controller->_loadingWindowNib);
          mode=2;
          @autoreleasepool { [controller loadWindow]; }
          assert(calls==3 && alive==1 && destroyed==2 && controller->_window && !controller->_loadingWindowNib);
          [controller loadWindow]; assert(calls==3);
          reenter=NO; [controller release];
      }
      assert(alive==0 && destroyed==3);
      puts("Base loader recursion, failure/exception retry and top-level ownership tests passed (controlled NIB loader)");
  }
OBJC
program=program.sub('ACTUAL_METHOD') { method }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('window-loader-host') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,
    "-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
