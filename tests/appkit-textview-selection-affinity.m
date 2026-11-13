// Links AppKit. -[NSTextView selectionAffinity] answers the affinity the selection was last set with.
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
        [view setString:@"some text"];
        [view setSelectedRange:NSMakeRange(2, 0) affinity:NSSelectionAffinityDownstream stillSelecting:NO];
        expect([view selectionAffinity] == NSSelectionAffinityDownstream, @"downstream");
        [view setSelectedRange:NSMakeRange(2, 0) affinity:NSSelectionAffinityUpstream stillSelecting:NO];
        expect([view selectionAffinity] == NSSelectionAffinityUpstream, @"upstream");
        NSLog(@"appkit-textview-selection-affinity: ok");
    }
    return 0;
}
