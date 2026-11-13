#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/CGSSessionSPI.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// The session dictionary keys. kCGSSessionUserNameKey is the string CGSession.h defines for
// kCGSessionUserNameKey (public macOS 11.3 SDK header mirror); the long name key has no public string (GUESS).
int main(void) {
    EXPECT(kCGSSessionUserNameKey != NULL, "kCGSSessionUserNameKey exists");
    EXPECT(CFEqual(kCGSSessionUserNameKey, CFSTR("kCGSSessionUserNameKey")), "the user name key is the documented string");
    EXPECT(kCGSSessionLongUserNameKey != NULL, "kCGSSessionLongUserNameKey exists");
    EXPECT(!CFEqual(kCGSSessionLongUserNameKey, kCGSSessionUserNameKey), "the long name key differs from the user name key");
    printf("PASS: CGS session keys\n");
    return 0;
}
