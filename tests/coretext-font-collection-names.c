#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

// The five NSFontCollection name constants that Font Book imports from CoreText, against the strings a real Mac printed
// for them (macOS 26.1, our own probe symbols_d_probe1: lines 64-68 of its output).
int main(void) {
    static const struct { const char *name; const char *value; } expected[] = {
        {"NSFontCollectionAllFonts", "com.apple.AllFonts"},                    // probe1:64
        {"NSFontCollectionUser", "com.apple.UserFonts"},                       // probe1:65
        {"NSFontCollectionFavorites", "com.apple.Favorites"},                  // probe1:66
        {"NSFontCollectionRecentlyUsed", "com.apple.Recents"},                 // probe1:67
        {"NSFontCollectionDidChangeNotification", "NSFontCollectionDidChange"}, // probe1:68
    };
    for (unsigned i = 0; i < sizeof expected / sizeof expected[0]; i++) {
        const char *name = expected[i].name;
        CFStringRef *symbol = (CFStringRef *) dlsym(RTLD_DEFAULT, name);
        if (symbol == NULL) { printf("FAIL: %s: is not exported\n", name); return 1; }
        char buffer[64];
        if (*symbol == NULL || CFGetTypeID(*symbol) != CFStringGetTypeID() ||
            !CFStringGetCString(*symbol, buffer, sizeof buffer, kCFStringEncodingUTF8)) {
            printf("FAIL: %s: is not a CFString\n", name); return 1;
        }
        if (strcmp(buffer, expected[i].value) != 0) {
            printf("FAIL: %s: value is \"%s\", a real Mac has \"%s\"\n", name, buffer, expected[i].value);
            return 1;
        }
    }
    printf("PASS: NSFontCollection names\n");
    return 0;
}
