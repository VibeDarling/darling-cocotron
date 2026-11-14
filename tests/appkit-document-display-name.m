// Link with candidate AppKit; no windows are needed.
#import <AppKit/NSDocument.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// System Information's document class does not declare setDisplayName:; it expects NSDocument to answer it.
@interface SPDocument : NSDocument
@end
@implementation SPDocument
@end

@interface NameObserver : NSObject {
@public
    int _changes;
}
@end
@implementation NameObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqual:@"displayName"]) _changes++;
}
@end

int main(void) {
    @autoreleasepool {
        SPDocument *document = [SPDocument new];
        expect([document respondsToSelector:@selector(setDisplayName:)], @"NSDocument answers setDisplayName:");

        NSString *untitled = [[document displayName] copy];
        expect([untitled length] > 0, @"an unnamed document has a default display name");

        NameObserver *observer = [NameObserver new];
        [document addObserver:observer forKeyPath:@"displayName" options:0 context:NULL];

        NSMutableString *name = [NSMutableString stringWithString:@"System Report"];
        @try {
            [document setDisplayName:name];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"setDisplayName: raised %@", [exception reason]]);
        }
        expect([[document displayName] isEqualToString:@"System Report"], @"the display name is the one set");
        [name appendString:@" edited"];
        expect([[document displayName] isEqualToString:@"System Report"], @"the display name is a copy");
        expect([[document valueForKey:@"displayName"] isEqualToString:@"System Report"], @"displayName key reads it");
        expect(observer->_changes == 1, @"setDisplayName: notifies displayName observers");

        [document setValue:@"Second" forKey:@"displayName"];
        expect([[document displayName] isEqualToString:@"Second"], @"displayName key writes it");

        [document setDisplayName:nil];
        expect([[document displayName] isEqualToString:untitled], @"nil goes back to the default name");

        [document removeObserver:observer forKeyPath:@"displayName"];
        [observer release];
        [untitled release];
        [document release];
    }
    printf("PASS: document display name\n");
    return 0;
}
