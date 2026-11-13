#import <Foundation/Foundation.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CADisplay is private; Weather imports the class at launch. It must exist, and a selector nothing defines
// must fail loudly as an unrecognized selector.
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    Class display = NSClassFromString(@"CADisplay");
    EXPECT(display != Nil, "CADisplay exists");
    EXPECT(![display respondsToSelector: @selector(mainDisplay)], "no invented class method");
    id instance = [display new];
    EXPECT(instance != nil, "an instance can be created");
    EXPECT(![instance respondsToSelector: @selector(name)], "no invented instance method");
    BOOL raised = NO;
    @try {
        [instance performSelector: @selector(name)];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqualToString: NSInvalidArgumentException];
    }
    EXPECT(raised, "a message the class does not define raises NSInvalidArgumentException");
    [instance release];
    [pool drain];
    printf("PASS: CADisplay\n");
    return 0;
}
