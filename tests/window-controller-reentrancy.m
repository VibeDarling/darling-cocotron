// Compile/link against the candidate AppKit and run in Darling.
#import <AppKit/AppKit.h>
#include <assert.h>

@interface ReentrantController : NSWindowController {
@public
    NSUInteger willCount, loadCount, didCount;
    BOOL throwDuringLoad;
}
@end

@implementation ReentrantController
- (void) windowWillLoad {
    willCount++;
    assert(willCount < 4);
    assert([self window] == nil);
}
- (void) loadWindow {
    loadCount++;
    assert(loadCount < 4);
    assert([self window] == nil);
    if (throwDuringLoad)
        [NSException raise: @"ProbeFailure" format: @"intentional"];
    // No window is created: permits a second attempt without a GUI backend.
}
- (void) windowDidLoad {
    didCount++;
    assert(didCount < 4);
    assert([self window] == nil);
}
@end

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    ReentrantController *controller = [[ReentrantController alloc]
            initWithWindowNibName: @"NoFileRequiredByOverride"];
    assert([controller window] == nil);
    assert(controller->willCount == 1 && controller->loadCount == 1 &&
           controller->didCount == 1);
    controller->throwDuringLoad = YES;
    BOOL caught = NO;
    @try { [controller window]; }
    @catch (NSException *exception) {
        caught = [[exception name] isEqualToString: @"ProbeFailure"];
    }
    assert(caught && controller->didCount == 1);
    controller->throwDuringLoad = NO;
    assert([controller window] == nil);
    assert(controller->willCount == 3 && controller->loadCount == 3 &&
           controller->didCount == 2);
    [controller release];
    [pool drain];
    return 0;
}
