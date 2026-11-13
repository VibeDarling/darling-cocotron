// Links AppKit. The private -[NSAppearance _isFunctionRowAppearance] answers NO for every appearance: there is no Touch
// Bar function row here (a GUESS from the name, rung 6).
#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        SEL selector = NSSelectorFromString(@"_isFunctionRowAppearance");
        NSAppearance *aqua = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        NSAppearance *touchBar = [NSAppearance appearanceNamed:NSAppearanceNameTouchBar];
        if (![aqua respondsToSelector:selector] || ![touchBar respondsToSelector:selector])
        {
            NSLog(@"FAIL: _isFunctionRowAppearance is not answered");
            exit(1);
        }
        if (((BOOL (*)(id, SEL))objc_msgSend)(aqua, selector) || ((BOOL (*)(id, SEL))objc_msgSend)(touchBar, selector))
        {
            NSLog(@"FAIL: no appearance is a function row appearance here");
            exit(1);
        }
        NSLog(@"appkit-appearance-is-function-row: ok");
    }
    return 0;
}
