// Links AppKit. -[NSTextView selectionGranularity] answers the granularity of the selection: by character after the
// selection is set programmatically.
#import <AppKit/AppKit.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        [view setString:@"some text"];
        [view setSelectedRange:NSMakeRange(1, 3)];
        if ([view selectionGranularity] != NSSelectByCharacter)
        {
            NSLog(@"FAIL: a selection set from code is by character");
            exit(1);
        }
        NSLog(@"appkit-textview-selection-granularity: ok");
    }
    return 0;
}
