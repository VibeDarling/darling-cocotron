#include <CoreText/CoreText.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s: %s\n", name, msg); return 1; } } while (0)

// The CoreText names that Books, Font Book and App Store import: string constants that no public header declares
// (found with dlsym, as an app's dyld bind finds them) and one CGFloat. Each string must be a CFString and no two
// may be equal: the values are GUESS, but a category, style or design is only useful if it differs from the others.
static const char *names[] = {
    "kCTFontUIFontDesignDefault", "kCTFontUIFontDesignTrait", "kCTFontUIFontDesignRounded",
    "kCTUIFontTextStyleBody", "kCTUIFontTextStyleCallout", "kCTUIFontTextStyleCaption1",
    "kCTUIFontTextStyleCaption2", "kCTUIFontTextStyleFootnote", "kCTUIFontTextStyleHeadline",
    "kCTUIFontTextStyleShortBody", "kCTUIFontTextStyleShortCaption1", "kCTUIFontTextStyleShortFootnote",
    "kCTUIFontTextStyleShortHeadline", "kCTUIFontTextStyleShortSubhead", "kCTUIFontTextStyleSubhead",
    "kCTUIFontTextStyleTallBody", "kCTUIFontTextStyleTitle0", "kCTUIFontTextStyleTitle1",
    "kCTUIFontTextStyleTitle2", "kCTUIFontTextStyleTitle3",
    "kCTFontDescriptorTextStyleAttribute", "kCTFontDesignLanguagesAttribute", "kCTFontOpticalSizeAttribute",
    "kCTFontDownloadableAttribute", "kCTFontDownloadedAttribute", "kCTFontDescriptorMatchingPercentage",
    "kCTFontAssetType", "kCTFontAssetFontInfoKey", "kCTFontCollectionIncludeStubFontsOption",
    "kCTFontManagerAvailableFontURLsAddedKey", "kCTFontManagerAvailableFontURLsRemovedKey",
    "kCTFontValidationOptionRunDynamic", "kCTFontValidationResults",
};
enum { count = sizeof names / sizeof names[0] };

int main(void) {
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
    const char *name = "kCTFontWidthExtraCompressed";
    CGFloat *width = (CGFloat *) dlsym(RTLD_DEFAULT, name);
    EXPECT(width != NULL, "is exported");
    EXPECT(isfinite(*width) && *width >= -1.0 && *width < 0.0, "is a compressed width inside the trait range");
    printf("PASS: CoreText SPI constants\n");
    return 0;
}
