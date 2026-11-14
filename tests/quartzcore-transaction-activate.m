#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include <stdio.h>

// Mac Catalyst clients send +[CATransaction activate] (not in the public documentation) and abort on an unrecognized
// selector. Darling accepts it without side effects: it opens no explicit transaction (+hasOpenTransaction counts only
// explicitly begun groups, so an implicit group is not covered) and leaves an open one open.
// GUESS: those two side-effect assertions pin the stand-in, not a known contract; a real implementation may change them.
static BOOL hasOpenTransaction(void) {
    return ((BOOL (*)(id, SEL)) objc_msgSend)([CATransaction class], NSSelectorFromString(@"hasOpenTransaction"));
}

int main(void) {
    @autoreleasepool {
        SEL selector = NSSelectorFromString(@"activate");
        BOOL responds = [CATransaction respondsToSelector: selector];
        BOOL passed = responds;
        if (responds) {
            ((void (*)(id, SEL)) objc_msgSend)([CATransaction class], selector);
            passed &= !hasOpenTransaction();
            [CATransaction begin];
            ((void (*)(id, SEL)) objc_msgSend)([CATransaction class], selector);
            passed &= hasOpenTransaction();
            [CATransaction commit];
            passed &= !hasOpenTransaction();
        }
        printf("transaction activate: responds=%d %s\n", responds, passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
