#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Notes binds NSSharingServiceNameCloudSharing at launch. The SDK header declares it (macOS 10.12) without a value;
// the test checks that it is exported, is a non-empty string and differs from the other service names. The value
// itself is a guess (see the source).
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSString *const *slot = (NSString *const *) dlsym(RTLD_DEFAULT, "NSSharingServiceNameCloudSharing");
    EXPECT(slot != NULL, "NSSharingServiceNameCloudSharing is exported");
    NSString *name = *slot;
    EXPECT([name isKindOfClass: [NSString class]] && [name length] > 0, "it is a non-empty string");
    EXPECT(![name isEqualToString: NSSharingServiceNameComposeEmail], "it differs from the compose email service");
    EXPECT(![name isEqualToString: NSSharingServiceNameComposeMessage], "it differs from the compose message service");
    EXPECT(![name isEqualToString: NSSharingServiceNameAddToIPhoto], "it differs from the add to iPhoto service");
    EXPECT(![name isEqualToString: NSSharingServiceNameAddToSafariReadingList], "it differs from the reading list service");
    [pool drain];
    printf("PASS: NSSharingServiceNameCloudSharing\n");
    return 0;
}
