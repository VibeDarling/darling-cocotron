// Links AppKit. Recording the attributes of an empty range, or in an empty text storage, for undo does not ask the storage
// for attributes at an index it does not have (a storage that rejects an index past its end, as the shared cache's does,
// would raise): -[NSTextView setFont:] with undo enabled on an empty view reaches it.
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

int main(void)
{
    @autoreleasepool
    {
        StrictStorage *storage = [[StrictStorage alloc] init];
        NSLayoutManager *layout = [[NSLayoutManager alloc] init];
        [layout setTextStorage:storage];
        NSUndoManager *undo = [[NSUndoManager alloc] init];

        Class operation = NSClassFromString(@"NSUndoSetAttributes");
        if (operation == Nil)
        {
            NSLog(@"FAIL: NSUndoSetAttributes is not there");
            exit(1);
        }
        @try {
            id recorded = [[operation alloc] initWithAffectedRange:NSMakeRange(0, 0) layoutManager:layout undoManager:undo];
            if (recorded == nil)
            {
                NSLog(@"FAIL: nothing recorded");
                exit(1);
            }
        } @catch (NSException *e) {
            NSLog(@"FAIL: the empty storage was asked for attributes: %@", e);
            exit(1);
        }
        NSLog(@"appkit-textview-undo-attributes-empty-range: ok");
    }
    return 0;
}
