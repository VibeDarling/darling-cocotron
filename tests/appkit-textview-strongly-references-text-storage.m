// Links AppKit. +[NSTextView stronglyReferencesTextStorage] exists and answers YES, which is what this implementation
// does: a text view made with -initWithFrame: retains its text storage and releases it when it goes.
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
        expect([NSTextView stronglyReferencesTextStorage], @"the class answers YES");

        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
        NSTextStorage *storage = [view textStorage];
        expect(storage != nil, @"the view has a storage");
        NSUInteger held = [storage retainCount];
        [view release];
        expect([storage retainCount] == held - 1, @"the view held a reference to its storage and gave it up");
        NSLog(@"appkit-textview-strongly-references-text-storage: ok");
    }
    return 0;
}
