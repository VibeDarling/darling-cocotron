#include <CoreText/CoreText.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// kCTFontUIFontDesignSerif is CoreText SPI that Books' BooksUI imports (no public header), so it is found
// through dlsym. It must be a non-empty CFString. The value is GUESS; the test checks the one thing the code
// promises, that it is the string AppKit's NSFontDescriptorSystemDesignSerif already carries.
int main(void) {
    CFStringRef *symbol = (CFStringRef *) dlsym(RTLD_DEFAULT, "kCTFontUIFontDesignSerif");
    EXPECT(symbol != NULL, "kCTFontUIFontDesignSerif is exported");
    EXPECT(*symbol != NULL && CFGetTypeID(*symbol) == CFStringGetTypeID(), "it is a CFString");
    EXPECT(CFStringGetLength(*symbol) > 0, "it is not empty");
    EXPECT(CFEqual(*symbol, CFSTR("NSCTFontUIFontDesignSerif")), "it is the string AppKit uses for the serif design");
    printf("PASS: kCTFontUIFontDesignSerif\n");
    return 0;
}
