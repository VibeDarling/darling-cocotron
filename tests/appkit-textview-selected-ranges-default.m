// Links AppKit. -[NSTextView selectedRanges] never answers nil: with nothing selected it is the insertion point at 0, also
// for a view asked before its designated initializer has run.
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
        NSTextView *early = [NSTextView alloc];
        NSArray *ranges = [early selectedRanges];
        expect(ranges != nil && [ranges count] == 1 && NSEqualRanges([[ranges objectAtIndex:0] rangeValue], NSMakeRange(0, 0)),
               @"an uninitialized view answers the insertion point at 0");

        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        ranges = [view selectedRanges];
        expect([ranges count] == 1 && NSEqualRanges([[ranges objectAtIndex:0] rangeValue], NSMakeRange(0, 0)), @"a new view too");
        [view setString:@"some text"];
        [view setSelectedRange:NSMakeRange(2, 3)];
        expect(NSEqualRanges([[[view selectedRanges] objectAtIndex:0] rangeValue], NSMakeRange(2, 3)), @"and follows the selection");
        NSLog(@"appkit-textview-selected-ranges-default: ok");
    }
    return 0;
}
