// Links AppKit. The private -[NSArray indexOfFirstRangeContainingOrFollowing:] is answered by AppKit, whichever Foundation serves
// NSArray: the index of the first range value that contains the character index or lies at or after it, NSNotFound when every
// range ends before it (a GUESS from the name, rung 6).
#import <AppKit/AppKit.h>
#import <objc/message.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSUInteger find(NSArray *ranges, NSUInteger index)
{
    return ((NSUInteger (*)(id, SEL, NSUInteger))objc_msgSend)(ranges, NSSelectorFromString(@"indexOfFirstRangeContainingOrFollowing:"), index);
}

int main(void)
{
    @autoreleasepool
    {
        NSArray *caret = @[[NSValue valueWithRange:NSMakeRange(0, 0)]];
        expect([caret respondsToSelector:NSSelectorFromString(@"indexOfFirstRangeContainingOrFollowing:")], @"the selector is answered");
        expect(find(caret, 0) == 0, @"an insertion point at the index contains it");

        NSArray *ranges = @[[NSValue valueWithRange:NSMakeRange(2, 3)], [NSValue valueWithRange:NSMakeRange(10, 4)]];
        expect(find(ranges, 0) == 0, @"a range after the index follows it");
        expect(find(ranges, 2) == 0, @"a range starting at the index contains it");
        expect(find(ranges, 4) == 0, @"a range around the index contains it");
        expect(find(ranges, 5) == 1, @"a range ending at the index (exclusive) is behind it");
        expect(find(ranges, 12) == 1, @"the second range contains 12");
        expect(find(ranges, 14) == NSNotFound, @"every range ends before 14");
        expect(find(@[], 0) == NSNotFound, @"an empty array has no range");

        NSLog(@"appkit-array-range-search: ok");
    }
    return 0;
}
