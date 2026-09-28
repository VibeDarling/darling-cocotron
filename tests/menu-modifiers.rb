# Actual NSMenu method with GNUstep strings/arrays and controlled event/action adapters.
# Usage: ruby tests/menu-modifiers.rb GNUSTEP_ROOT [NSMenu.m]
require 'tmpdir'
require 'open3'
sdk = ARGV.fetch(0)
source = File.read(ARGV[1] || File.expand_path('../AppKit/NSMenu.subproj/NSMenu.m', __dir__))
method = source[/^- \(BOOL\) performKeyEquivalent:.*?^\}/m]
abort 'method missing' unless method
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  enum { NSShiftKeyMask=1<<17, NSControlKeyMask=1<<18,
         NSAlternateKeyMask=1<<19, NSCommandKeyMask=1<<20 };
  static unsigned eventFlags, sends, updates;
  static NSString *characters;
  static BOOL dispatchResult=YES;
  static id lastItem;
  @interface NSEvent : NSObject @end
  @implementation NSEvent
  - (NSString *)charactersIgnoringModifiers { return characters; }
  - (unsigned)modifierFlags { return eventFlags; }
  @end
  @interface NSMenuItem : NSObject {
  @public unsigned flags; NSString *key; id child; BOOL enabled;
  }
  @end
  @implementation NSMenuItem
  - (unsigned)keyEquivalentModifierMask { return flags; }
  - (NSString *)keyEquivalent { return key; }
  - (id)submenu { return child; }
  - (SEL)action { return @selector(description); }
  - (id)target { return self; }
  @end
  static BOOL itemIsEnabled(NSMenuItem *item) { return item->enabled; }
  @interface App : NSObject @end
  @implementation App
  - (BOOL)sendAction:(SEL)action to:(id)target from:(id)item {
      assert(action == @selector(description) && target == item);
      ++sends; lastItem=item; return dispatchResult;
  }
  @end
  static App *NSApp;
  @interface Menu : NSObject {
  @public NSArray *_itemArray; BOOL _autoenablesItems;
  }
  - (BOOL)performKeyEquivalent:(NSEvent *)event;
  @end
  @implementation Menu
  - (void)update { ++updates; }
  ACTUAL_METHOD
  @end
  int main(void) {
    @autoreleasepool {
      NSApp=[App new]; NSEvent *event=[NSEvent new];
      Menu *menu=[Menu new]; NSMenuItem *item=[NSMenuItem new];
      menu->_itemArray=@[item]; item->enabled=YES;
      item->key=characters=@"x";
      for(unsigned b=0;b<16;++b) for(unsigned e=0;e<16;++e) {
        item->flags=b<<17; eventFlags=(e<<17)|(1<<16)|(1<<21);
        sends=0;
        assert([menu performKeyEquivalent:event] == (b==e));
        assert(sends == (b==e));
      }
      // Uppercase representation contributes Shift; supplied characters remain exact.
      item->key=characters=@"X"; item->flags=NSCommandKeyMask;
      eventFlags=NSCommandKeyMask|NSShiftKeyMask; sends=0;
      assert([menu performKeyEquivalent:event] && sends==1);
      eventFlags=NSCommandKeyMask; sends=0;
      assert(![menu performKeyEquivalent:event] && !sends);
      eventFlags|=NSShiftKeyMask; characters=@"x";
      assert(![menu performKeyEquivalent:event] && !sends);
      characters=@"X"; item->enabled=NO;
      assert(![menu performKeyEquivalent:event] && !sends);
      item->enabled=YES; dispatchResult=NO;
      assert(![menu performKeyEquivalent:event] && sends==1);
      dispatchResult=YES;
      Menu *submenu=[Menu new]; NSMenuItem *nested=[NSMenuItem new];
      nested->key=@"z"; nested->flags=NSControlKeyMask; nested->enabled=YES;
      submenu->_itemArray=@[nested]; item->child=submenu;
      characters=@"z"; eventFlags=NSControlKeyMask; sends=updates=0;
      menu->_autoenablesItems=YES;
      assert([menu performKeyEquivalent:event]);
      assert(sends==1 && lastItem==nested && updates==1);
      menu->_itemArray=@[]; sends=0;
      assert(![menu performKeyEquivalent:event] && !sends);
      [nested release]; [submenu release]; [item release];
      [menu release]; [event release]; [NSApp release];
      puts("PASS: 256 modifier combinations, implicit Shift, exact characters, validation gate, dispatch result, submenu and empty menu");
    }
  }
OBJC
program = program.sub('ACTUAL_METHOD') { method }
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'GCC headers unavailable' unless status.success?
Dir.mktmpdir('menu-modifiers') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'test failed' unless system(output, rlimit_core: 0)
end
