// Links AppKit. The private -[NSTextView _informTextFinderStringWillChange] exists and is a no-op: there is no text
// finder client here, so it changes nothing (a GUESS from the name, as the other private AppKit no-ops).
#import <AppKit/AppKit.h>
#include <stdlib.h>

int main(void)
{
    @autoreleasepool
    {
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        [view setString:@"unchanged"];
        SEL selector = NSSelectorFromString(@"_informTextFinderStringWillChange");
        if (![view respondsToSelector:selector])
        {
            NSLog(@"FAIL: _informTextFinderStringWillChange is not answered");
            exit(1);
        }
        [view performSelector:selector];
        if (![[view string] isEqualToString:@"unchanged"])
        {
            NSLog(@"FAIL: the text changed");
            exit(1);
        }
        NSLog(@"appkit-textview-inform-text-finder-string-will-change: ok");
    }
    return 0;
}
