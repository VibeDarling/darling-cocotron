#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <stdio.h>

// Mac Catalyst clients read +[NSScroller clickBehavior] (not in the public documentation) and abort on an unrecognized
// selector. Darling answers 0; the return type and the meaning of 0 are GUESS.
int main(void) {
    @autoreleasepool {
        SEL selector = NSSelectorFromString(@"clickBehavior");
        BOOL responds = [NSScroller respondsToSelector: selector];
        NSInteger value = responds ? ((NSInteger (*)(id, SEL)) objc_msgSend)([NSScroller class], selector) : -1;
        BOOL passed = responds && value == 0 && ![NSScroller instancesRespondToSelector: selector];
        printf("scroller click behavior: responds=%d value=%ld %s\n", responds, (long) value, passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
