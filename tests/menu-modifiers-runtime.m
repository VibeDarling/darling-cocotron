#import <AppKit/AppKit.h>
#include <assert.h>
#include <stdio.h>
#ifdef NDEBUG
#error This regression requires assertions
#endif
@interface ShortcutTarget : NSObject { @public unsigned calls; id sender; }
- (void)activate:(id)value;
@end
@implementation ShortcutTarget
- (void)activate:(id)value { ++calls; sender=value; }
@end
static NSEvent *key(NSString *characters, NSUInteger flags) {
    return [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint
        modifierFlags:flags timestamp:0 windowNumber:0 context:nil
        characters:characters charactersIgnoringModifiers:characters
        isARepeat:NO keyCode:0];
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        ShortcutTarget *target=[ShortcutTarget new];
        NSMenu *menu=[[NSMenu alloc] initWithTitle:@"Regression"];
        [menu setAutoenablesItems:NO];
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"Action"
            action:@selector(activate:) keyEquivalent:@"x"];
        [item setTarget:target];
        [menu addItem:item];
        for (unsigned expected=0;expected<16;++expected) {
            [item setKeyEquivalentModifierMask:expected<<17];
            for (unsigned event=0;event<16;++event) {
                target->calls=0; target->sender=nil;
                NSString *characters=(event & 1) ? @"X" : @"x";
                BOOL handled=[menu performKeyEquivalent:key(characters,event<<17)];
                assert(handled==(expected==event));
                assert(target->calls==(expected==event));
                if (handled) assert(target->sender==item);
            }
        }
        [item setKeyEquivalent:@"X"];
        [item setKeyEquivalentModifierMask:NSCommandKeyMask];
        target->calls=0;
        assert([menu performKeyEquivalent:key(@"X",NSCommandKeyMask|NSShiftKeyMask)]);
        assert(target->calls==1);
        [item setEnabled:NO]; target->calls=0;
        assert(![menu performKeyEquivalent:key(@"X",NSCommandKeyMask|NSShiftKeyMask)]);
        assert(!target->calls);
        [item release]; [menu release]; [target release];
        puts("PASS: real AppKit menu modifier matrix and action dispatch");
    }
    return 0;
}
