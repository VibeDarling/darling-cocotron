#import <AppKit/AppKit.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// NSSharingServiceItemProvider is private: the class exists and answers nothing beyond NSObject.
// (NSSharingServicePickerToolbarItem, which this branch added first, is VibeDarling/darling-cocotron#561's.)
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    Class providerClass = NSClassFromString(@"NSSharingServiceItemProvider");
    EXPECT(providerClass != Nil, "NSSharingServiceItemProvider exists");
    id instance = [providerClass new];
    EXPECT(instance != nil, "an instance can be created");
    EXPECT(![instance respondsToSelector: @selector(registeredTypeIdentifiers)], "it answers no invented selector");
    [instance release];
    [pool drain];
    printf("PASS: sharing service item provider\n");
    return 0;
}
