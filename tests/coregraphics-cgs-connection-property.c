#include <CoreGraphics/CoreGraphics.h>
#include <CoreGraphics/CGSServerSPI.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGSSetConnectionProperty and CGSCopyConnectionProperty (prototypes from WebKit's CoreGraphicsSPI.h): a
// property set under an owner connection and key is copied back (retained) under the same pair only.
int main(void) {
    CFStringRef key = CFSTR("com.example.property");
    CFStringRef other = CFSTR("com.example.other");
    CFTypeRef value = NULL;

    EXPECT(CGSCopyConnectionProperty(1, 7, key, &value) == kCGErrorSuccess && value == NULL, "an unset property copies as NULL");
    CFStringRef first = CFStringCreateWithFormat(NULL, NULL, CFSTR("first %d"), 1); // heap string: a real retain count
    CFIndex before = CFGetRetainCount(first);
    EXPECT(CGSSetConnectionProperty(1, 7, key, first) == kCGErrorSuccess, "set succeeds");
    EXPECT(CGSCopyConnectionProperty(1, 7, key, &value) == kCGErrorSuccess && value != NULL, "a set property is copied back");
    EXPECT(CFEqual(value, first), "the copied value is the set one");
    EXPECT(CFGetRetainCount(first) == before + 2, "the table and the copy each hold a reference");
    CFRelease(value);

    EXPECT(CGSSetConnectionProperty(1, 7, key, CFSTR("second")) == kCGErrorSuccess, "a property can be replaced");
    CGSCopyConnectionProperty(1, 7, key, &value);
    EXPECT(value != NULL && CFEqual(value, CFSTR("second")), "the replacement wins");
    CFRelease(value);

    CGSCopyConnectionProperty(1, 8, key, &value);
    EXPECT(value == NULL, "another owner connection does not see the property");
    CGSCopyConnectionProperty(1, 7, other, &value);
    EXPECT(value == NULL, "another key does not see the property");

    EXPECT(CGSSetConnectionProperty(1, 7, key, NULL) == kCGErrorSuccess, "a NULL value clears the property");
    CGSCopyConnectionProperty(1, 7, key, &value);
    EXPECT(value == NULL, "a cleared property copies as NULL");

    EXPECT(CGSSetConnectionProperty(1, 7, NULL, CFSTR("x")) == kCGErrorIllegalArgument, "a NULL key is rejected");
    EXPECT(CGSCopyConnectionProperty(1, 7, key, NULL) == kCGErrorIllegalArgument, "a NULL result pointer is rejected");
    printf("PASS: connection properties\n");
    return 0;
}
