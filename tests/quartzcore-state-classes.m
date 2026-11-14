#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CAState and CAStateController are private; FindMy imports them at launch, together with the string constant
// kCAPackageTypeCAMLBundle. Each class must exist, and a selector nothing defines must fail loudly as an
// unrecognized selector. The constant's value is a GUESS in the implementation, so only its type is checked.
static int checkClass(const char *name) {
    Class cls = NSClassFromString(@(name));
    EXPECT(cls != Nil, "the class exists");
    id instance = [cls new];
    EXPECT(instance != nil, "an instance can be created");
    BOOL raised = NO;
    @try {
        [instance performSelector: @selector(invalidInventedSelectorForTest)];
    } @catch (NSException *exception) {
        raised = [[exception name] isEqualToString: NSInvalidArgumentException];
    }
    EXPECT(raised, "a message the class does not define raises NSInvalidArgumentException");
    [instance release];
    return 0;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    if (checkClass("CAState") || checkClass("CAStateController")) return 1;
    NSString *const *slot = (NSString *const *) dlsym(RTLD_DEFAULT, "kCAPackageTypeCAMLBundle");
    EXPECT(slot != NULL, "kCAPackageTypeCAMLBundle is exported");
    EXPECT([*slot isKindOfClass: [NSString class]] && [*slot length] > 0, "kCAPackageTypeCAMLBundle is a non-empty string");
    [pool drain];
    printf("PASS: CAState, CAStateController, kCAPackageTypeCAMLBundle\n");
    return 0;
}
