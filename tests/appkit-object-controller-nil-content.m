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

// A controller whose content is bound later (TextEdit's Document Properties panel binds its fields to
// the selection of such a controller while the nib is loading) has no content yet: no selected objects.
int main(void)
{
    @autoreleasepool
    {
        NSObjectController *controller = [[NSObjectController alloc] initWithContent:nil];
        NSArray *selected = nil;
        @try
        {
            selected = [controller selectedObjects];
        }
        @catch (NSException *exception)
        {
            expect(NO, [NSString stringWithFormat:@"selectedObjects raised %@: %@", exception.name, exception.reason]);
        }
        expect(selected != nil && [selected count] == 0, @"no content, no selected objects");
        expect([[controller selection] valueForKey:@"anything"] == NSNoSelectionMarker, @"the selection proxy reports no selection");

        [controller setContent:@"value"];
        expect([[controller selectedObjects] count] == 1 && [[controller selectedObjects][0] isEqual:@"value"], @"content is the selection");
        NSLog(@"PASS: object controller without content has no selected objects");
    }
    return 0;
}
