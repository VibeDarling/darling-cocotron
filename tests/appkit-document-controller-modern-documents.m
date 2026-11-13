// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Apps send this private class method to NSDocumentController.
@interface NSDocumentController (ModernDocumentsProbe)
+ (void)_setUsingModernDocuments:(BOOL)flag;
@end

int main(void) {
    @autoreleasepool {
        expect([NSDocumentController respondsToSelector:@selector(_setUsingModernDocuments:)],
               @"NSDocumentController answers +_setUsingModernDocuments:");

        NSDocumentController *controller = [NSDocumentController sharedDocumentController];
        NSTimeInterval delay = [controller autosavingDelay];

        @try {
            [NSDocumentController _setUsingModernDocuments:YES];
            [NSDocumentController _setUsingModernDocuments:NO];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"the call returns without raising: %@", [exception reason]]);
        }

        // The call changes nothing the controller reports.
        expect([NSDocumentController sharedDocumentController] == controller, @"the shared controller is unchanged");
        expect([[controller documents] count] == 0, @"no document appears");
        expect([controller autosavingDelay] == delay, @"the autosaving delay is unchanged");
        NSLog(@"PASS: +_setUsingModernDocuments:");
    }
    return 0;
}
