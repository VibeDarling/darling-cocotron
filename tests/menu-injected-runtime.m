#import <AppKit/AppKit.h>
#include <assert.h>
#include <stdio.h>
#ifdef NDEBUG
#error Assertions required
#endif
@interface InjectedTarget : NSObject { @public NSInteger last; unsigned calls; }
- (void)activate:(id)sender;
@end
@implementation InjectedTarget
- (void)activate:(id)sender { last=[sender tag]; ++calls; }
@end
int main(void) {
    @autoreleasepool {
        setbuf(stdout,NULL);
        [NSApplication sharedApplication];
        NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(50,50,300,150)
            styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
        [window setTitle:@"ShortcutInjection"];
        [window makeKeyAndOrderFront:nil];
        NSMenu *menu=[[NSMenu alloc] initWithTitle:@"Probe"];
        [menu setAutoenablesItems:NO];
        InjectedTarget *target=[InjectedTarget new];
        NSUInteger masks[]={NSCommandKeyMask,NSCommandKeyMask|NSShiftKeyMask,
                            NSCommandKeyMask|NSControlKeyMask};
        for(unsigned i=0;i<3;++i) {
            NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"Action"
                action:@selector(activate:) keyEquivalent:@"x"];
            [item setTarget:target]; [item setTag:i+1];
            [item setKeyEquivalentModifierMask:masks[i]];
            [menu addItem:item]; [item release];
        }
        NSInteger expected[]={1,2,1,3};
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:12];
        unsigned received=0;
        while(received<4 && [deadline timeIntervalSinceNow]>0) {
            NSEvent *event=[NSApp nextEventMatchingMask:NSAnyEventMask
                untilDate:deadline inMode:NSDefaultRunLoopMode dequeue:YES];
            if(!event) break;
            if([event type]!=NSKeyDown) { [NSApp sendEvent:event]; continue; }
            NSString *characters=[event charactersIgnoringModifiers];
            if(![characters isEqualToString:@"x"] && ![characters isEqualToString:@"X"]) continue;
            printf("KEY %u flags=%lu chars=%s\n",received,(unsigned long)[event modifierFlags],[characters UTF8String]);
            assert([characters isEqualToString:received==1 ? @"X" : @"x"]);
            unsigned before=target->calls;
            assert([menu performKeyEquivalent:event]);
            assert(target->calls==before+1 && target->last==expected[received]);
            ++received;
        }
        assert(received==4);
        puts("PASS: injected X11 keys reach correct menu actions including Caps Lock");
    }
    return 0;
}
