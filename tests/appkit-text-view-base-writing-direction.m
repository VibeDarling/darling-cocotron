#import <AppKit/AppKit.h>
#include <stdlib.h>

// NSText.h (macOS 10.0) declares baseWritingDirection on NSText. Script Editor's script view subclasses NSTextView
// without declaring it and expects NSTextView to answer it, like -setAlignment:, for all of the text.
@interface SEScriptView : NSTextView
@end
@implementation SEScriptView
@end

static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSWritingDirection directionAt(NSTextView *view, NSUInteger index) {
    NSParagraphStyle *style = [[view textStorage] attribute: NSParagraphStyleAttributeName
                                                    atIndex: index
                                             effectiveRange: NULL];
    return style ? [style baseWritingDirection] : [[NSParagraphStyle defaultParagraphStyle] baseWritingDirection];
}

int main(void) {
    @autoreleasepool {
        SEScriptView *view = [[[SEScriptView alloc] initWithFrame: NSMakeRect(0, 0, 300, 100)] autorelease];
        expect([view respondsToSelector: @selector(setBaseWritingDirection:)], @"the text view answers setBaseWritingDirection:");
        expect([view respondsToSelector: @selector(baseWritingDirection)], @"the text view answers baseWritingDirection");
        expect([view baseWritingDirection] == [[NSParagraphStyle defaultParagraphStyle] baseWritingDirection],
               @"a new text view has the default paragraph style's direction");

        [view setString: @"first\nsecond"];
        NSUInteger last = [[view string] length] - 1;

        @try {
            [view setBaseWritingDirection: NSWritingDirectionRightToLeft];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat: @"setBaseWritingDirection: raised %@", [exception reason]]);
        }
        expect([view baseWritingDirection] == NSWritingDirectionRightToLeft, @"right to left reads back");
        expect(directionAt(view, 0) == NSWritingDirectionRightToLeft, @"the first paragraph is right to left");
        expect(directionAt(view, last) == NSWritingDirectionRightToLeft, @"the last paragraph is right to left");

        [view setBaseWritingDirection: NSWritingDirectionLeftToRight];
        expect([view baseWritingDirection] == NSWritingDirectionLeftToRight, @"left to right reads back");
        expect(directionAt(view, last) == NSWritingDirectionLeftToRight, @"the last paragraph is left to right");

        [view setBaseWritingDirection: NSWritingDirectionNatural];
        expect([view baseWritingDirection] == NSWritingDirectionNatural, @"natural reads back");
        expect(directionAt(view, 0) == NSWritingDirectionNatural, @"the first paragraph is natural");

        // An empty view takes the direction too.
        SEScriptView *empty = [[[SEScriptView alloc] initWithFrame: NSMakeRect(0, 0, 300, 100)] autorelease];
        [empty setBaseWritingDirection: NSWritingDirectionRightToLeft];
        expect([empty baseWritingDirection] == NSWritingDirectionRightToLeft, @"an empty view reads back right to left");
    }
    printf("PASS: text view base writing direction\n");
    return 0;
}
