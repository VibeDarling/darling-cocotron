// Links AppKit. -[NSTextView setConstrainedFrameSize:] sets the frame size within the view's minimum and maximum
// size on the axes that can resize, and leaves an axis that cannot resize alone.
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
        [view setMinSize:NSMakeSize(20, 10)];
        [view setMaxSize:NSMakeSize(200, 300)];
        [view setHorizontallyResizable:YES];
        [view setVerticallyResizable:YES];

        [view setConstrainedFrameSize:NSMakeSize(150, 80)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(150, 80)), @"a size within the limits is taken");
        [view setConstrainedFrameSize:NSMakeSize(500, 5)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(200, 10)), @"above the maximum and below the minimum are clamped");

        [view setConstrainedFrameSize:NSMakeSize(150, 900)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(150, 300)), @"a height above the maximum is clamped to it");
        [view setConstrainedFrameSize:NSMakeSize(900, 80)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(200, 80)), @"a width above the maximum is clamped to it");
        [view setConstrainedFrameSize:NSMakeSize(5, 80)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(20, 80)), @"a width below the minimum is raised to it");

        [view setConstrainedFrameSize:NSMakeSize(200, 40)];
        [view setHorizontallyResizable:NO];
        [view setConstrainedFrameSize:NSMakeSize(120, 40)];
        expect([view frame].size.width == 200 && [view frame].size.height == 40, @"an axis that cannot resize keeps its length");

        [view setVerticallyResizable:NO];
        [view setConstrainedFrameSize:NSMakeSize(1, 1)];
        expect(NSEqualSizes([view frame].size, NSMakeSize(200, 40)), @"neither axis resizes");
        NSLog(@"appkit-textview-constrained-frame-size: ok");
    }
    return 0;
}
