// Links AppKit. -[NSTextView invalidateTextContainerOrigin] exists, leaves the origin where the inset puts it, and
// has the view draw again.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        [view setTextContainerInset:NSMakeSize(7, 3)];
        [view setNeedsDisplay:NO];
        [view invalidateTextContainerOrigin];
        expect([view needsDisplay], @"the view is marked for drawing");
        expect(NSEqualPoints([view textContainerOrigin], NSMakePoint(7, 3)), @"the origin follows the inset");
        [view setTextContainerInset:NSMakeSize(1, 2)];
        [view invalidateTextContainerOrigin];
        expect(NSEqualPoints([view textContainerOrigin], NSMakePoint(1, 2)), @"and follows a changed inset");
        NSLog(@"appkit-textview-invalidate-text-container-origin: ok");
    }
    return 0;
}
