#include <CoreText/CoreText.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s: %s\n", name, msg); return 1; } } while (0)

// Four documented CTStringAttributes names (kCTHorizontalInVerticalFormsAttributeName, kCTStrokeColorAttributeName,
// kCTTabColumnTerminatorsAttributeName, kCTWritingDirectionAttributeName) that Freeform imports. Each must be
// exported as a CFString, and no two may be equal, nor equal to an attribute name this CoreText already had: the
// values are GUESS, but an attribute key is only useful if it differs from the others.
int main(void) {
    static const char *names[] = {
        "kCTHorizontalInVerticalFormsAttributeName", "kCTStrokeColorAttributeName",
        "kCTTabColumnTerminatorsAttributeName", "kCTWritingDirectionAttributeName",
        "kCTFontAttributeName", "kCTParagraphStyleAttributeName", "kCTForegroundColorAttributeName",
        "kCTStrokeWidthAttributeName", "kCTKernAttributeName", "kCTLanguageAttributeName",
        "kCTVerticalFormsAttributeName",
    };
    enum { count = sizeof names / sizeof names[0] };
    CFStringRef values[count];
    for (int i = 0; i < count; i++) {
        const char *name = names[i];
        CFStringRef *symbol = (CFStringRef *) dlsym(RTLD_DEFAULT, name);
        EXPECT(symbol != NULL, "is exported");
        EXPECT(*symbol != NULL && CFGetTypeID(*symbol) == CFStringGetTypeID(), "is a CFString");
        values[i] = *symbol;
        for (int j = 0; j < i; j++) {
            EXPECT(!CFEqual(values[j], values[i]), "differs from the names before it");
        }
    }
    printf("PASS: CTStringAttributes names\n");
    return 0;
}
