// Links AppKit. The private -[NSTextView _updateTextFinder] exists and is a no-op: there is no text finder client
// here, so it changes nothing (a GUESS from the name, as the other private AppKit no-ops).
#import <AppKit/AppKit.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        [view setString:@"unchanged"];
        SEL update = NSSelectorFromString(@"_updateTextFinder");
        if (![view respondsToSelector:update])
        {
            NSLog(@"FAIL: _updateTextFinder is not answered");
            exit(1);
        }
        [view performSelector:update];
        if (![[view string] isEqualToString:@"unchanged"])
        {
            NSLog(@"FAIL: the text changed");
            exit(1);
        }
        NSLog(@"appkit-textview-update-text-finder: ok");
    }
    return 0;
}
