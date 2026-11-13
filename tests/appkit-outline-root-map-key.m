#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface Source : NSObject
@end

@implementation Source
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item == nil ? 2 : 0;
}
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    return index == 0 ? @"first" : @"second";
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return NO;
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)column byItem:(id)item
{
    return item;
}
@end

// The map tables of the outline view must not hold a nil key: the root item is nil, and Apple's NSMapTable
// (used when AppKit runs on Apple's Foundation) crashes on a nil key in NSMapInsert.
int main(void)
{
    @autoreleasepool
    {
        Source *source = [[Source alloc] init];
        NSOutlineView *outline = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300)];
        NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"name"] autorelease];
        [outline addTableColumn:column];
        outline.outlineTableColumn = column;
        outline.dataSource = (id)source;
        [outline reloadData];
        expect(outline.numberOfRows == 2, @"root children are rows");

        const char *names[] = { "_rowToItem", "_itemToRow", "_itemToParent", "_itemToLevel", "_itemToExpansionState", "_itemToNumberOfChildren" };
        for (unsigned i = 0; i < sizeof names / sizeof names[0]; i++)
        {
            Ivar ivar = class_getInstanceVariable([NSOutlineView class], names[i]);
            expect(ivar != NULL, [NSString stringWithFormat:@"%s exists", names[i]]);
            NSMapTable *table = *(NSMapTable **)((char *)outline + ivar_getOffset(ivar));
            expect(table != NULL, [NSString stringWithFormat:@"%s is created", names[i]]);
            NSMapEnumerator enumerator = NSEnumerateMapTable(table);
            void *key, *value;
            // _rowToItem is keyed by row number, where 0 is a valid key; every other table is keyed by items.
            while (NSNextMapEnumeratorPair(&enumerator, &key, &value))
                expect(i == 0 || key != NULL, [NSString stringWithFormat:@"%s holds no nil key", names[i]]);
            NSEndMapTableEnumeration(&enumerator);
        }

        expect([outline levelForItem:nil] == -1, @"the root item has no level");
        expect([outline parentForItem:nil] == nil, @"the root item has no parent");
        NSLog(@"PASS: outline view map tables hold no nil key");
    }
    return 0;
}
