// Link with candidate AppKit; no windows are needed.
#import <AppKit/NSDocument.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

@interface AutosaveDocument : NSDocument {
@public
    BOOL _safe;
    int _autosaves;
}
@end
@implementation AutosaveDocument
- (BOOL)checkAutosavingSafetyAndReturnError:(NSError **)outError {
    if (!_safe && outError)
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    return _safe;
}
- (void)autosaveWithImplicitCancellability:(BOOL)cancellable
                         completionHandler:(void (^)(NSError *))handler {
    _autosaves++;
    handler(nil);
}
@end

int main(void) {
    @autoreleasepool {
        NSDocument *plain = [NSDocument new];
        expect([plain checkAutosavingSafetyAndReturnError:NULL], @"the default document is safe to autosave");
        expect([plain respondsToSelector:@selector(_checkAutosavingThenContinue:)],
               @"NSDocument answers -_checkAutosavingThenContinue:");

        // The continuation runs once, with the answer of -checkAutosavingSafetyAndReturnError:.
        __block int calls = 0;
        __block BOOL proceed = NO;
        [plain _checkAutosavingThenContinue:^(BOOL ok) { calls++; proceed = ok; }];
        expect(calls == 1 && proceed, @"a safe document continues with YES, once");

        // A subclass is asked through its own documented override, and nothing is saved.
        AutosaveDocument *document = [AutosaveDocument new];
        document->_safe = YES;
        calls = 0; proceed = NO;
        [document _checkAutosavingThenContinue:^(BOOL ok) { calls++; proceed = ok; }];
        expect(document->_autosaves == 0, @"checking does not autosave");
        expect(calls == 1 && proceed, @"a safe subclass continues with YES");

        document->_safe = NO;
        calls = 0; proceed = YES;
        [document _checkAutosavingThenContinue:^(BOOL ok) { calls++; proceed = ok; }];
        expect(calls == 1 && !proceed, @"an unsafe document continues with NO");
        expect(document->_autosaves == 0, @"an unsafe document is not autosaved");

        // A nil continuation is allowed.
        [document _checkAutosavingThenContinue:nil];

        // A block of another shape raises and is not called.
        BOOL raised = NO;
        calls = 0;
        @try {
            [document _checkAutosavingThenContinue:(void (^)(BOOL))^(id other) { calls++; }];
        } @catch (NSException *exception) {
            raised = [[exception name] isEqualToString:NSInvalidArgumentException];
        }
        expect(raised && calls == 0, @"a block that does not take one BOOL raises and is not called");

        [document release];
        [plain release];
        NSLog(@"PASS: -_checkAutosavingThenContinue:");
    }
    return 0;
}
