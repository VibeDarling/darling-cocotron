#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <stdio.h>

// Mac Catalyst clients send the private class messages +setHandleUIKeyCommandEvent: and
// +setIsUIKeyCommandEvent: to NSTextInputContext. Without the selectors the message raises
// "unrecognized selector sent to class". The methods are private and undeclared, so the test
// reaches them through the runtime. The methods accept and ignore the value; the check is that
// each class method exists, accepts both values and leaves the instance side untouched.
static int checkSetter(const char *name)
{
    SEL setter = sel_registerName(name);
    Class cls = [NSTextInputContext class];

    if (![cls respondsToSelector:setter]) {
        fprintf(stderr, "FAIL: +[NSTextInputContext %s] is missing\n", name);
        return 1;
    }

    NSTextInputContext *instance = [NSTextInputContext currentInputContext];
    if ([instance respondsToSelector:setter]) {
        fprintf(stderr, "FAIL: %s must be a class method only\n", name);
        return 1;
    }

    @try {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(cls, setter, YES);
        ((void (*)(id, SEL, BOOL))objc_msgSend)(cls, setter, NO);
    } @catch (NSException *exception) {
        fprintf(stderr, "FAIL: +%s raised %s: %s\n", name,
                [[exception name] UTF8String], [[exception reason] UTF8String]);
        return 1;
    }

    printf("PASS: +[NSTextInputContext %s] accepts YES and NO\n", name);
    return 0;
}

int main(void)
{
    int failed = 0;
    @autoreleasepool {
        failed |= checkSetter("setHandleUIKeyCommandEvent:");
        failed |= checkSetter("setIsUIKeyCommandEvent:");
    }
    return failed;
}
