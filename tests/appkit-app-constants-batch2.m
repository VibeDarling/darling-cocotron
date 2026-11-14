#import <AppKit/AppKit.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Three string constants that stock applications bind at launch. The SDK header NSWorkspace.h declares
// NSWorkspaceMoveOperation (next to the other file operations). NSSharingServiceNameUseAsAccountPicture and
// NSAppleMenuName are exported by AppKit but declared in no public header, so the test declares them itself.
// Each must exist and differ from its siblings.
extern NSString *const NSSharingServiceNameUseAsAccountPicture;
extern NSString *const NSAppleMenuName;

int main(void) {
    EXPECT(NSWorkspaceMoveOperation != nil, "NSWorkspaceMoveOperation exists");
    EXPECT(![NSWorkspaceMoveOperation isEqualToString: NSWorkspaceRecycleOperation], "Move differs from Recycle");
    EXPECT(![NSWorkspaceMoveOperation isEqualToString: NSWorkspaceDuplicateOperation], "Move differs from Duplicate");

    EXPECT(NSSharingServiceNameUseAsAccountPicture != nil, "NSSharingServiceNameUseAsAccountPicture exists");
    EXPECT(![NSSharingServiceNameUseAsAccountPicture isEqualToString: NSSharingServiceNameComposeEmail], "account picture differs from ComposeEmail");
    EXPECT(![NSSharingServiceNameUseAsAccountPicture isEqualToString: NSSharingServiceNameAddToIPhoto], "account picture differs from AddToIPhoto");

    EXPECT(NSAppleMenuName != nil && [NSAppleMenuName length] > 0, "NSAppleMenuName exists");
    printf("PASS: batch 2 string constants\n");
    return 0;
}
