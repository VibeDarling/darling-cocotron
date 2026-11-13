// Links AppKit. A text view starting out on an empty text storage does not ask the storage for attributes at index 0:
// a storage that rejects an index past its end (as the shared cache's does) would raise. The private
// -[NSTextView _copyInitialTypingAttributes] is what -initWithCoder: and the storage setter use for it.
#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface StrictStorage : NSTextStorage {
    NSMutableAttributedString *backing;
}
@end

@implementation StrictStorage
- (id)init { backing = [[NSMutableAttributedString alloc] init]; return [super init]; }
- (NSString *)string { return [backing string]; }
- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range
{
    if (index >= [backing length])
        [NSException raise:NSRangeException format:@"index %lu beyond the end", (unsigned long)index];
    return [backing attributesAtIndex:index effectiveRange:range];
}
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string { [backing replaceCharactersInRange:range withString:string]; }
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range { [backing setAttributes:attributes range:range]; }
@end

// A keyed coder that answers what -[NSTextView initWithCoder:] asks of a nib, with the text container prepared by the test
// and zero or nil for the rest.
@interface FakeNibCoder : NSCoder {
    NSTextContainer *container;
}
- (id)initWithContainer:(NSTextContainer *)aContainer;
@end

@implementation FakeNibCoder
- (id)initWithContainer:(NSTextContainer *)aContainer { container = [aContainer retain]; return [super init]; }
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)containsValueForKey:(NSString *)key { return NO; }
- (id)decodeObjectForKey:(NSString *)key { return [key isEqualToString:@"NSTextContainer"] ? container : nil; }
- (int)decodeIntForKey:(NSString *)key { return 0; }
- (int32_t)decodeInt32ForKey:(NSString *)key { return 0; }
- (int64_t)decodeInt64ForKey:(NSString *)key { return 0; }
- (BOOL)decodeBoolForKey:(NSString *)key { return NO; }
- (float)decodeFloatForKey:(NSString *)key { return 0; }
- (double)decodeDoubleForKey:(NSString *)key { return 0; }
@end

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
        StrictStorage *storage = [[StrictStorage alloc] init];
        NSLayoutManager *layout = [[NSLayoutManager alloc] init];
        [layout setTextStorage:storage];
        NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(100, 100)];
        [layout addTextContainer:container];
        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50) textContainer:container];

        SEL selector = NSSelectorFromString(@"_copyInitialTypingAttributes");
        expect([view respondsToSelector:selector], @"the helper exists");
        NSDictionary *empty = nil;
        @try {
            empty = [view performSelector:selector];
        } @catch (NSException *e) {
            expect(NO, @"an empty storage is not asked for attributes");
        }
        expect(empty != nil && [empty count] == 0, @"an empty storage gives no attributes");
        [empty release];

        // The nib path: -initWithCoder: seeds the typing attributes from the same empty storage.
        StrictStorage *nibStorage = [[StrictStorage alloc] init];
        NSLayoutManager *nibLayout = [[NSLayoutManager alloc] init];
        [nibLayout setTextStorage:nibStorage];
        NSTextContainer *nibContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(100, 100)];
        [nibLayout addTextContainer:nibContainer];
        FakeNibCoder *coder = [[FakeNibCoder alloc] initWithContainer:nibContainer];
        NSTextView *decoded = nil;
        @try {
            decoded = [[NSTextView alloc] initWithCoder:coder];
        } @catch (NSException *e) {
            expect(NO, [NSString stringWithFormat:@"initWithCoder: asked the empty storage for attributes: %@", e]);
        }
        expect(decoded != nil, @"the view decodes on an empty storage");
        expect([decoded textStorage] == nibStorage, @"and takes the storage of the prepared container");
        NSLog(@"appkit-textview-initial-typing-attributes: ok");
    }
    return 0;
}
