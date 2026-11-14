#include <CoreText/CoreText.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s: %s\n", name, msg); return 1; } } while (0)

// The twelve content size categories that Books' BooksUI imports from CoreText. They are CoreText SPI (the
// names are not in a public header), so the test finds them through dlsym. Each must be a CFString and no two
// may be equal: the values are GUESS, but a category is only useful if it differs from the others.
int main(void) {
    static const char *names[] = {
        "kCTFontContentSizeCategoryXS", "kCTFontContentSizeCategoryS", "kCTFontContentSizeCategoryM",
        "kCTFontContentSizeCategoryL", "kCTFontContentSizeCategoryXL", "kCTFontContentSizeCategoryXXL",
        "kCTFontContentSizeCategoryXXXL", "kCTFontContentSizeCategoryAccessibilityM",
        "kCTFontContentSizeCategoryAccessibilityL", "kCTFontContentSizeCategoryAccessibilityXL",
        "kCTFontContentSizeCategoryAccessibilityXXL", "kCTFontContentSizeCategoryAccessibilityXXXL",
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
            EXPECT(!CFEqual(values[j], values[i]), "differs from the categories before it");
        }
    }
    printf("PASS: content size categories\n");
    return 0;
}
