// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Apps send this private class method to NSMenu.
@interface NSMenu (SidebandProbe)
+ (void)_setAlwaysCallDelegateBeforeSidebandUpdaters:(BOOL)flag;
@end

int main(void) {
    @autoreleasepool {
        expect([NSMenu respondsToSelector:@selector(_setAlwaysCallDelegateBeforeSidebandUpdaters:)],
               @"NSMenu answers +_setAlwaysCallDelegateBeforeSidebandUpdaters:");
        @try {
            [NSMenu _setAlwaysCallDelegateBeforeSidebandUpdaters:YES];
            [NSMenu _setAlwaysCallDelegateBeforeSidebandUpdaters:NO];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"the call returns without raising: %@", [exception reason]]);
        }

        // The call changes nothing a menu shows.
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"probe"];
        [menu addItemWithTitle:@"one" action:NULL keyEquivalent:@""];
        expect([menu numberOfItems] == 1, @"a menu still holds its items");
        [menu release];
        NSLog(@"PASS: +_setAlwaysCallDelegateBeforeSidebandUpdaters:");
    }
    return 0;
}
