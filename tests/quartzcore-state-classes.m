#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CAState and CAStateController are private; FindMy imports them at launch, together with the string constant
// kCAPackageTypeCAMLBundle. Each class must exist, and a selector nothing defines must fail loudly as an
// unrecognized selector. The constant's value is the one a real Mac printed (macOS 26.1, probe 11 section 1,
// darling_probe11.txt line 39). Both classes exist on the real Mac (line 42-43); their superclass was not observed.
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
    EXPECT([*slot isKindOfClass: [NSString class]] && [*slot isEqualToString: @"com.apple.coreanimation-bundle"], "kCAPackageTypeCAMLBundle has the observed value");
    [pool drain];
    printf("PASS: CAState, CAStateController, kCAPackageTypeCAMLBundle\n");
    return 0;
}
