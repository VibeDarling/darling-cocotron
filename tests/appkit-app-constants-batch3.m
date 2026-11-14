#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Two string constants stock applications bind at launch. The public SDK headers declare
// NSToolbarToggleSidebarItemIdentifier (NSToolbarItem.h) and NSSharingServiceNameSendViaAirDrop
// (NSSharingService.h) without a value, so the test checks that each is exported, is a non-empty string
// and differs from its siblings. The values themselves are guesses (see the sources).
static NSString *constant(const char *name) {
    NSString *const *slot = (NSString *const *) dlsym(RTLD_DEFAULT, name);
    return slot ? *slot : nil;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    NSString *toggle = constant("NSToolbarToggleSidebarItemIdentifier");
    EXPECT(toggle != nil, "NSToolbarToggleSidebarItemIdentifier is exported");
    EXPECT([toggle isKindOfClass: [NSString class]] && [toggle length] > 0, "it is a non-empty string");
    EXPECT(![toggle isEqualToString: NSToolbarSpaceItemIdentifier], "it differs from the space item");
    EXPECT(![toggle isEqualToString: NSToolbarFlexibleSpaceItemIdentifier], "it differs from the flexible space item");
    EXPECT(![toggle isEqualToString: NSToolbarPrintItemIdentifier], "it differs from the print item");

    NSString *airDrop = constant("NSSharingServiceNameSendViaAirDrop");
    EXPECT(airDrop != nil, "NSSharingServiceNameSendViaAirDrop is exported");
    EXPECT([airDrop isKindOfClass: [NSString class]] && [airDrop length] > 0, "it is a non-empty string");
    EXPECT(![airDrop isEqualToString: NSSharingServiceNameComposeEmail], "it differs from ComposeEmail");
    EXPECT(![airDrop isEqualToString: NSSharingServiceNameComposeMessage], "it differs from ComposeMessage");
    EXPECT(![airDrop isEqualToString: NSSharingServiceNameAddToIPhoto], "it differs from AddToIPhoto");

    [pool drain];
    printf("PASS: batch 3 string constants\n");
    return 0;
}
