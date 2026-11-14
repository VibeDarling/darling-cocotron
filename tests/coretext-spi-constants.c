#include <CoreText/CoreText.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s: %s\n", name, msg); return 1; } } while (0)

// The CoreText names that Books, Font Book and App Store import (SPI that no public header declares, found with dlsym
// as an app's dyld bind finds them, and four documented attribute names). The expected strings and the CGFloat are
// the values a real Mac printed for the same names (macOS 26.1, our own probe symbols_d_probe1; the line of its
// output is on each row), so a stand-in that answers with any other string fails here. The table is typed from the
// probe output, not computed from the stand-in's source.
static const struct { const char *name; const char *value; } expected[] = {
    {"kCTFontUIFontDesignTrait", "NSCTFontUIFontDesignTrait"}, // probe1:3
    {"kCTFontUIFontDesignDefault", "NSCTFontUIFontDesignDefault"}, // probe1:4
    {"kCTFontUIFontDesignRounded", "NSCTFontUIFontDesignRounded"}, // probe1:6
    {"kCTUIFontTextStyleBody", "UICTFontTextStyleBody"}, // probe1:8
    {"kCTUIFontTextStyleCallout", "UICTFontTextStyleCallout"}, // probe1:9
    {"kCTUIFontTextStyleCaption1", "UICTFontTextStyleCaption1"}, // probe1:10
    {"kCTUIFontTextStyleCaption2", "UICTFontTextStyleCaption2"}, // probe1:11
    {"kCTUIFontTextStyleFootnote", "UICTFontTextStyleFootnote"}, // probe1:12
    {"kCTUIFontTextStyleHeadline", "UICTFontTextStyleHeadline"}, // probe1:13
    {"kCTUIFontTextStyleShortBody", "UICTFontTextStyleShortBody"}, // probe1:14
    {"kCTUIFontTextStyleShortCaption1", "UICTFontTextStyleShortCaption1"}, // probe1:15
    {"kCTUIFontTextStyleShortFootnote", "UICTFontTextStyleShortFootnote"}, // probe1:16
    {"kCTUIFontTextStyleShortHeadline", "UICTFontTextStyleShortHeadline"}, // probe1:17
    {"kCTUIFontTextStyleShortSubhead", "UICTFontTextStyleShortSubhead"}, // probe1:18
    {"kCTUIFontTextStyleSubhead", "UICTFontTextStyleSubhead"}, // probe1:19
    {"kCTUIFontTextStyleTallBody", "UICTFontTextStyleTallBody"}, // probe1:20
    {"kCTUIFontTextStyleTitle0", "UICTFontTextStyleTitle0"}, // probe1:21
    {"kCTUIFontTextStyleTitle1", "UICTFontTextStyleTitle1"}, // probe1:22
    {"kCTUIFontTextStyleTitle2", "UICTFontTextStyleTitle2"}, // probe1:23
    {"kCTUIFontTextStyleTitle3", "UICTFontTextStyleTitle3"}, // probe1:24
    {"kCTFontDescriptorTextStyleAttribute", "NSCTFontUIUsageAttribute"}, // probe1:26
    {"kCTFontOpticalSizeAttribute", "NSCTFontOpticalSizeAttribute"}, // probe1:40
    {"kCTFontDesignLanguagesAttribute", "NSCTFontDesignLanguagesAttribute"}, // probe1:41
    {"kCTFontDownloadableAttribute", "NSCTFontDownloadableAttribute"}, // probe1:42
    {"kCTFontDownloadedAttribute", "NSCTFontDownloadedAttribute"}, // probe1:43
    {"kCTFontDescriptorMatchingPercentage", "CTFontDescriptorMatchingPercentage"}, // probe1:44
    {"kCTFontAssetType", "com.apple.MobileAsset.Font8"}, // probe1:45
    {"kCTFontAssetFontInfoKey", "FontInfo4"}, // probe1:46
    {"kCTFontCollectionIncludeStubFontsOption", "NSCTFontCollectionIncludeStubFontsOption"}, // probe1:47
    {"kCTFontManagerAvailableFontURLsAddedKey", "CTFontManagerAvailableFontURLsAdded"}, // probe1:48
    {"kCTFontManagerAvailableFontURLsRemovedKey", "CTFontManagerAvailableFontURLsRemoved"}, // probe1:49
    {"kCTFontValidationOptionRunDynamic", "dynamic"}, // probe1:50
    {"kCTFontValidationResults", "results"}, // probe1:51
};

int main(void) {
    for (unsigned i = 0; i < sizeof expected / sizeof expected[0]; i++) {
        const char *name = expected[i].name;
        CFStringRef *symbol = (CFStringRef *) dlsym(RTLD_DEFAULT, name);
        EXPECT(symbol != NULL, "is exported");
        EXPECT(*symbol != NULL && CFGetTypeID(*symbol) == CFStringGetTypeID(), "is a CFString");
        char buffer[128];
        EXPECT(CFStringGetCString(*symbol, buffer, sizeof buffer, kCFStringEncodingUTF8), "is printable");
        if (strcmp(buffer, expected[i].value) != 0) {
            printf("FAIL: %s: value is \"%s\", a real Mac has \"%s\"\n", name, buffer, expected[i].value);
            return 1;
        }
    }
    const char *name = "kCTFontWidthExtraCompressed";
    CGFloat *width = (CGFloat *) dlsym(RTLD_DEFAULT, name);
    EXPECT(width != NULL, "is exported");
    EXPECT(*width == -0.4, "is -0.4 (probe1:54)");
    printf("PASS: CoreText SPI constants\n");
    return 0;
}
