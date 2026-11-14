#import <CoreText/CTFontManager.h>
#import <CoreText/CTFontDescriptor.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSURL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <limits.h>
#include <sys/stat.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("CTFontManagerFontChangedNotification");

bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef* error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef *error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return nil;
}

CFArrayRef CTFontManagerCopyAvailableFontFamilyNames(void)
{
    NSArray *families = [NSArray arrayWithObjects:
        @"Helvetica",
        @"Times",
        @"Courier",
        @"Arial",
        @"Menlo",
        @"Monaco",
        @"Geneva",
        @"Symbol",
        @"Apple Color Emoji",
        nil];
    return (CFArrayRef)[families copy];
}

CFArrayRef CTFontManagerCreateFontDescriptorsFromData(CFDataRef data)
{
    if (!data) return (CFArrayRef)[[NSArray array] retain];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    if (!provider) return (CFArrayRef)[[NSArray array] retain];
    CGFontRef cgFont = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!cgFont) {
        // Font data format could not be parsed by FreeType/Onyx2D
        return (CFArrayRef)[[NSArray array] retain];
    }
    CFStringRef name = CGFontCopyPostScriptName(cgFont);
    CTFontDescriptorRef desc = CTFontDescriptorCreateWithNameAndSize(name, 0);
    if (name) CFRelease(name);
    CGFontRelease(cgFont);
    if (!desc) return (CFArrayRef)[[NSArray array] retain];
    NSArray *result = [NSArray arrayWithObject:(id)desc];
    CFRelease(desc);
    return (CFArrayRef)[result retain];
}

// Synchronously loads font data from fontURL (local file or network URL).
// Network URLs may block if invoked from the main thread.
CFArrayRef CTFontManagerCreateFontDescriptorsFromURL(CFURLRef fontURL)
{
    if (!fontURL) return (CFArrayRef)[[NSArray array] retain];
    NSData *data = [NSData dataWithContentsOfURL:(NSURL *)fontURL];
    if (!data) return (CFArrayRef)[[NSArray array] retain];
    return CTFontManagerCreateFontDescriptorsFromData((CFDataRef)data);
}

bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef * error)
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
    return false;
}

// Four documented functions (Apple's CoreText documentation gives the prototypes and the meaning: macOS 10.6, and
// 10.15 for CTFontManagerUnregisterFontURLs) that Font Book imports. Observed on a real Mac (rung 4, macOS 26.1, our
// own probe symbols_d_probe1; the line of its output is quoted below) where noted.

// Observed (probe1:73-87): a file URL whose file exists, is a regular file, is not empty and has a font file extension
// is supported; the content is not read (a text file named .ttf is supported, the same bytes named .txt are not); a
// missing file, an empty file, a directory and a non-file URL are not. Observed extension: ttf. GUESS
// (NEEDS-REAL-MAC): the other extensions in the list.
bool CTFontManagerIsSupportedFont(CFURLRef fontURL)
{
    if (fontURL == NULL) return false;
    CFStringRef scheme = CFURLCopyScheme(fontURL);
    bool isFile = scheme != NULL && CFStringCompare(scheme, CFSTR("file"), kCFCompareCaseInsensitive) == kCFCompareEqualTo;
    if (scheme != NULL) CFRelease(scheme);
    char path[PATH_MAX];
    if (!isFile || !CFURLGetFileSystemRepresentation(fontURL, true, (UInt8 *)path, sizeof path)) return false;
    struct stat info;
    if (stat(path, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size == 0) return false;
    const char *dot = strrchr(path, '.');
    if (dot == NULL || strchr(dot, '/') != NULL) return false;
    static const char *const extensions[] = {"ttf", "otf", "ttc", "otc", "dfont"};
    for (size_t i = 0; i < sizeof extensions / sizeof extensions[0]; i++) {
        if (strcasecmp(dot + 1, extensions[i]) == 0) return true;
    }
    return false;
}

// Observed (probe1:88-90): unregistering a URL that is not registered calls the handler once, before the function
// returns, with one error and done true. The error has the domain below, code 201 and the three user-info entries
// below, the URL array holding the URL given. Nothing is ever registered in Cocotron (CTFontManagerRegisterFontsForURL
// is a stub here), so this is the only answer there is; darling-cocotron #517 registers fonts per process and has to
// make this function aware of them when it lands. GUESS (NEEDS-REAL-MAC, the probe passed one URL and process scope):
// several URLs give one error holding all of them, an empty or NULL array calls the handler with no error, and the
// other scopes behave the same.
void CTFontManagerUnregisterFontURLs(CFArrayRef fontURLs, CTFontManagerScope scope, bool (^registrationHandler)(CFArrayRef errors, bool done))
{
    if (registrationHandler == NULL) return;
    CFArrayRef errors;
    if (fontURLs == NULL || CFArrayGetCount(fontURLs) == 0) {
        errors = CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks);
    } else {
        const void *keys[] = {CFSTR("NSLocalizedDescription"), CFSTR("CTFontManagerErrorFontURLs"), CFSTR("NSLocalizedFailureReason")};
        const void *values[] = {CFSTR("The file is not registered in the specified scope."), fontURLs, CFSTR("Font unregistration was unsuccessful.")};
        CFDictionaryRef info = CFDictionaryCreate(NULL, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFErrorRef error = CFErrorCreate(NULL, CFSTR("com.apple.CoreText.CTFontManagerErrorDomain"), 201, info);
        errors = CFArrayCreate(NULL, (const void **)&error, 1, &kCFTypeArrayCallBacks);
        CFRelease(error);
        CFRelease(info);
    }
    registrationHandler(errors, true);
    CFRelease(errors);
}

// Not probed or not reproducible without a font registry, so each prints its name and aborts instead of answering with
// an invented value. CTFontManagerGetScopeForURL answered Persistent (2) for an installed system font and Process (1) for
// a font registered in the process (probe1:74, 93): the first needs the list of installed font files, the second a
// registry that CTFontManagerRegisterFontsForURL does not have here (#517 adds one). CTFontManagerEnableFontDescriptors
// was not probed.
static void notImplemented(const char *name)
{
    fprintf(stderr, "CoreText: %s is not implemented\n", name);
    abort();
}

CTFontManagerScope CTFontManagerGetScopeForURL(CFURLRef fontURL)
{
    notImplemented(__func__);
    return kCTFontManagerScopeNone;
}

void CTFontManagerEnableFontDescriptors(CFArrayRef descriptors, bool enable)
{
    notImplemented(__func__);
}
