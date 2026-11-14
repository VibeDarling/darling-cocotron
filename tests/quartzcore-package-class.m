#import <Foundation/Foundation.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CAPackage is private; FindMy imports the class at launch. It must exist, and a selector nothing defines
// must fail loudly as an unrecognized selector.
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    Class package = NSClassFromString(@"CAPackage");
    EXPECT(package != Nil, "CAPackage exists");
    EXPECT(![package respondsToSelector: @selector(packageWithContentsOfURL:type:options:error:)], "no invented class method");
    id instance = [package new];
    EXPECT(instance != nil, "an instance can be created");
    EXPECT(![instance respondsToSelector: @selector(rootLayer)], "no invented instance method");
    BOOL raised = NO;
    @try {
        [instance performSelector: @selector(rootLayer)];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqualToString: NSInvalidArgumentException];
    }
    EXPECT(raised, "a message the class does not define raises NSInvalidArgumentException");
    [instance release];
    [pool drain];
    printf("PASS: CAPackage\n");
    return 0;
}
