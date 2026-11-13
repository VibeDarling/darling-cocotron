// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Native constraint activation asks every item this question.
@interface NSObject (LegalConstraintItemProbe)
- (BOOL)nsli_isLegalConstraintItem;
@end

static void expectLegal(id item, NSString *what) {
    expect([item respondsToSelector:@selector(nsli_isLegalConstraintItem)],
           [NSString stringWithFormat:@"%@ answers nsli_isLegalConstraintItem", what]);
    expect([item nsli_isLegalConstraintItem],
           [NSString stringWithFormat:@"%@ is a legal constraint item", what]);
}

int main(void) {
    @autoreleasepool {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        expectLegal(view, @"a view");

        // Subclasses inherit the answer: a scroll view's clip view takes part in constraints.
        NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        expectLegal(scrollView, @"a scroll view");
        expectLegal([scrollView contentView], @"a clip view");

        // Real path: the native constraint factory and activation between plain views
        // must not raise. (The guest's native code accepts views even without the
        // answer, so this guards the path rather than failing on master.)
        NSView *child = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
        [view addSubview:child];
        @try {
            NSLayoutConstraint *constraint =
                [NSLayoutConstraint constraintWithItem:child attribute:NSLayoutAttributeLeft
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:view attribute:NSLayoutAttributeLeft
                                            multiplier:1 constant:10];
            expect(constraint != nil, @"constraintWithItem: between two views creates a constraint");
            [constraint setActive:YES];
            expect([[view constraints] count] == 1, @"activation installs the constraint on the common superview");
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"constraint between views raised %@: %@",
                        [exception name], [exception reason]]);
        }
        [child release];
        [scrollView release];
        [view release];
        NSLog(@"PASS: nsli_isLegalConstraintItem");
    }
    return 0;
}
