#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <stdio.h>

// Mac Catalyst clients ask the shared workspace whether the "use grayscale" display preference is on
// (-accessibilityDisplayShouldUseGrayscale, not in the public documentation) and abort on an unrecognized selector.
// Darling reports the standard, unmodified display mode like the other accessibility display preferences.
int main(void) {
    @autoreleasepool {
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        SEL selector = NSSelectorFromString(@"accessibilityDisplayShouldUseGrayscale");
        BOOL responds = [workspace respondsToSelector: selector];
        BOOL value = responds ? ((BOOL (*)(id, SEL)) objc_msgSend)(workspace, selector) : YES;
        BOOL passed = responds && !value;
        printf("workspace use grayscale: responds=%d value=%d %s\n", responds, value, passed ? "PASS" : "FAIL");
        return passed ? 0 : 1;
    }
}
