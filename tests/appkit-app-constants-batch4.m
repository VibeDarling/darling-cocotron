#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// String constants stock applications bind at launch. NSToolbarItem.h declares
// NSToolbarSidebarTrackingSeparatorItemIdentifier without a value; the NSFlowLayout...Key names are in no public
// header. The test checks that each is exported, is a non-empty string and differs from its neighbours;
// the values themselves are guesses (see the sources).
static NSString *constant(const char *name) {
    NSString *const *slot = (NSString *const *) dlsym(RTLD_DEFAULT, name);
    return slot ? *slot : nil;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    NSString *tracking = constant("NSToolbarSidebarTrackingSeparatorItemIdentifier");
    EXPECT(tracking != nil, "NSToolbarSidebarTrackingSeparatorItemIdentifier is exported");
    EXPECT([tracking isKindOfClass: [NSString class]] && [tracking length] > 0, "it is a non-empty string");
    EXPECT(![tracking isEqualToString: NSToolbarSeparatorItemIdentifier], "it differs from the separator item");
    EXPECT(![tracking isEqualToString: NSToolbarSpaceItemIdentifier], "it differs from the space item");
    EXPECT(![tracking isEqualToString: NSToolbarFlexibleSpaceItemIdentifier], "it differs from the flexible space item");

    NSString *alignment = constant("NSFlowLayoutCommonRowHorizontalAlignmentKey");
    EXPECT(alignment != nil, "NSFlowLayoutCommonRowHorizontalAlignmentKey is exported");
    EXPECT([alignment isKindOfClass: [NSString class]] && [alignment length] > 0, "it is a non-empty string");
    EXPECT(![alignment isEqualToString: NSCollectionElementKindSectionHeader], "it differs from the section header kind");
    EXPECT(![alignment isEqualToString: NSCollectionElementKindSectionFooter], "it differs from the section footer kind");
    EXPECT(![alignment isEqualToString: tracking], "the two constants differ");

    // Notes binds two more flow layout keys next to it; the next run would stop on them.
    NSString *lastRow = constant("NSFlowLayoutLastRowHorizontalAlignmentKey");
    NSString *vertical = constant("NSFlowLayoutRowVerticalAlignmentKey");
    EXPECT(lastRow != nil && [lastRow length] > 0, "NSFlowLayoutLastRowHorizontalAlignmentKey is an exported non-empty string");
    EXPECT(vertical != nil && [vertical length] > 0, "NSFlowLayoutRowVerticalAlignmentKey is an exported non-empty string");
    EXPECT(![lastRow isEqualToString: alignment] && ![vertical isEqualToString: alignment] && ![lastRow isEqualToString: vertical],
           "the three flow layout keys differ");

    [pool drain];
    printf("PASS: batch 4 string constants\n");
    return 0;
}
