// NSTrackingSeparatorToolbarItem keeps the split view and divider index it is
// made with; NSSplitViewItemAccessoryViewController keeps its two flags and
// starts with automaticallyAppliesContentInsets YES and hidden NO.
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
        NSSplitView *split = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        NSUInteger base = [split retainCount];
        NSTrackingSeparatorToolbarItem *item =
            [NSTrackingSeparatorToolbarItem trackingSeparatorToolbarItemWithIdentifier:@"sep"
                                                                             splitView:split
                                                                          dividerIndex:2];
        // Retain counts are read straight from the object: going through the
        // atomic getter would add an autoreleased retain and hide a miss.
        expect([split retainCount] == base + 1, @"the item retains the split view");
        NSTrackingSeparatorToolbarItem *dup = [item copy];
        expect([split retainCount] == base + 2, @"a copy retains the split view");
        [dup release];
        expect([split retainCount] == base + 1, @"releasing the copy gives the retain back");
        [split release];
        expect(item != nil, @"factory returns an item");
        expect([item isKindOfClass:[NSToolbarItem class]], @"item is an NSToolbarItem");
        expect([[item itemIdentifier] isEqual:@"sep"], @"identifier is kept");
        expect(item.splitView != nil && [item.splitView isKindOfClass:[NSSplitView class]],
               @"split view outlives the caller's reference");
        expect(item.dividerIndex == 2, @"divider index is kept");
        item.dividerIndex = 5;
        expect(item.dividerIndex == 5, @"divider index is settable");

        NSSplitViewItemAccessoryViewController *accessory =
            [[[NSSplitViewItemAccessoryViewController alloc] init] autorelease];
        expect([accessory isKindOfClass:[NSViewController class]], @"accessory is a view controller");
        expect(accessory.automaticallyAppliesContentInsets, @"insets default to YES");
        expect(!accessory.hidden, @"hidden defaults to NO");
        accessory.hidden = YES;
        accessory.automaticallyAppliesContentInsets = NO;
        expect(accessory.hidden && !accessory.automaticallyAppliesContentInsets, @"flags are settable");
        NSLog(@"PASS: toolbar and split view classes");
    }
    return 0;
}
