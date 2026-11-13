// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Apple frameworks look this private method up on NSApplication by name.
@interface NSApplication (SignpostProbe)
- (void)_emitApplicationLaunchSignpost;
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        expect(class_getInstanceMethod([NSApplication class], @selector(_emitApplicationLaunchSignpost)) != NULL,
               @"NSApplication has an instance method -_emitApplicationLaunchSignpost");
        @try {
            [app _emitApplicationLaunchSignpost];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"the call returns without raising: %@", [exception reason]]);
        }
        expect(![app isRunning], @"the call does not start the application");
        NSLog(@"PASS: -_emitApplicationLaunchSignpost");
    }
    return 0;
}
