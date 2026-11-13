// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Apps subclass NSApplication and send this private query to it.
@interface NSApplication (GestureMaskProbe)
- (NSEventMask)gestureEventMask;
@end

@interface MaskApplication : NSApplication
@end
@implementation MaskApplication
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [MaskApplication sharedApplication];
        expect([app isKindOfClass:[MaskApplication class]], @"the shared application is the subclass");
        expect([app respondsToSelector:@selector(gestureEventMask)], @"NSApplication answers -gestureEventMask");

        NSEventMask mask = [app gestureEventMask];
        expect(mask == (NSEventMaskMagnify | NSEventMaskRotate), @"the mask is the magnify and rotate event masks");
        expect(!(mask & NSEventMaskKeyDown) && !(mask & NSEventMaskLeftMouseDown), @"the mask holds no key or mouse event");
        NSLog(@"PASS: -gestureEventMask");
    }
    return 0;
}
