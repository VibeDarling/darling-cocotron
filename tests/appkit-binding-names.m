// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// NSTextColorBinding is public AppKit API (NSKeyValueBinding.h); like the other bindings its value is the
// bound key, which is what a nib's binding connection and -bind:toObject:withKeyPath:options: use.
// NSHelpManagerSystemBook has no public documentation: only its presence is asserted.
int main(void) {
    @autoreleasepool {
        expect([NSTextColorBinding isEqual:@"textColor"], @"NSTextColorBinding is the textColor key");
        expect(NSHelpManagerSystemBook != nil && [NSHelpManagerSystemBook length] > 0, @"NSHelpManagerSystemBook is a non-empty string");
        NSLog(@"PASS: binding names");
    }
    return 0;
}
