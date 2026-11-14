#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CTFontManagerIsSupportedFont and CTFontManagerUnregisterFontURLs against what a real Mac answered for the same inputs
// (macOS 26.1, our own probe symbols_d_probe1: lines 73-90 of its output). The functions are found with dlsym. Checks
// marked GUESS pin behaviour the probe did not observe; they are there so that a change of it is a conscious one.
typedef bool (*IsSupportedFont)(CFURLRef);
typedef void (*UnregisterFontURLs)(CFArrayRef, uint32_t, bool (^)(CFArrayRef, bool));

static char domain[128], description[128], reason[128];

static CFURLRef urlFor(const char *path) {
    return CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *) path, (CFIndex) strlen(path), false);
}

static void writeFile(const char *path, const char *text) {
    FILE *f = fopen(path, "wb");
    if (f) { fputs(text, f); fclose(f); }
}

int main(void) {
    IsSupportedFont isSupported = (IsSupportedFont) dlsym(RTLD_DEFAULT, "CTFontManagerIsSupportedFont");
    UnregisterFontURLs unregister = (UnregisterFontURLs) dlsym(RTLD_DEFAULT, "CTFontManagerUnregisterFontURLs");
    EXPECT(isSupported != NULL && unregister != NULL, "both functions are exported");

    char dir[] = "/tmp/coretext-font-manager-observed.XXXXXX";
    EXPECT(mkdtemp(dir) != NULL, "mkdtemp");
    char garbageTTF[256], textTXT[256], emptyTTF[256], missingTTF[256], upperTTF[256], dirTTF[256];
    snprintf(garbageTTF, sizeof garbageTTF, "%s/garbage.ttf", dir);
    snprintf(textTXT, sizeof textTXT, "%s/font.txt", dir);
    snprintf(emptyTTF, sizeof emptyTTF, "%s/empty.ttf", dir);
    snprintf(missingTTF, sizeof missingTTF, "%s/missing.ttf", dir);
    snprintf(upperTTF, sizeof upperTTF, "%s/UPPER.TTF", dir);
    snprintf(dirTTF, sizeof dirTTF, "%s/folder.ttf", dir);
    writeFile(upperTTF, "this is not a font\n");
    mkdir(dirTTF, 0700);
    writeFile(garbageTTF, "this is not a font\n");
    writeFile(textTXT, "this is not a font\n");
    writeFile(emptyTTF, "");

    // probe1:75, 77, 79, 81, 83, 85, 87
    CFURLRef u = urlFor(garbageTTF);
    bool garbage = isSupported(u); CFRelease(u);
    u = urlFor(textTXT);
    bool text = isSupported(u); CFRelease(u);
    u = urlFor(emptyTTF);
    bool empty = isSupported(u); CFRelease(u);
    u = urlFor(missingTTF);
    bool missing = isSupported(u); CFRelease(u);
    u = urlFor(dir);
    bool directory = isSupported(u); CFRelease(u);
    CFURLRef http = CFURLCreateWithString(NULL, CFSTR("http://example.invalid/a.ttf"), NULL);
    bool remote = isSupported(http); CFRelease(http);
    // GUESS (not observed on the Mac): upper case extension, a directory named x.ttf, a non-file URL whose path exists
    u = urlFor(upperTTF);
    bool upper = isSupported(u); CFRelease(u);
    u = urlFor(dirTTF);
    bool folder = isSupported(u); CFRelease(u);
    char remoteString[320];
    snprintf(remoteString, sizeof remoteString, "http://example.invalid%s", garbageTTF);
    CFStringRef remoteCF = CFStringCreateWithCString(NULL, remoteString, kCFStringEncodingUTF8);
    CFURLRef remoteExisting = CFURLCreateWithString(NULL, remoteCF, NULL);
    bool remoteHit = isSupported(remoteExisting); CFRelease(remoteExisting); CFRelease(remoteCF);
    unlink(garbageTTF); unlink(textTXT); unlink(emptyTTF); unlink(upperTTF); rmdir(dirTTF); rmdir(dir);
    EXPECT(garbage, "a non-empty file with a font extension is supported whatever it holds (probe1:79)");
    EXPECT(!text, "the same bytes under a .txt name are not supported (probe1:77)");
    EXPECT(!empty, "an empty .ttf is not supported (probe1:81)");
    EXPECT(!missing, "a missing file is not supported (probe1:83)");
    EXPECT(!directory, "a directory is not supported (probe1:85)");
    EXPECT(!remote, "a non-file URL is not supported (probe1:87)");
    EXPECT(!isSupported(NULL), "NULL is not supported");
    EXPECT(upper, "GUESS: an upper case font extension is supported");
    EXPECT(!folder, "GUESS: a directory named x.ttf is not supported");
    EXPECT(!remoteHit, "GUESS: a non-file URL is not supported even when its path exists");

    // probe1:88-90: one handler call, before the function returns, one error, done true
    CFURLRef font = urlFor("/tmp/never-registered.ttf");
    CFMutableArrayRef urls = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    CFArrayAppendValue(urls, font);
    __block int calls = 0, errorCount = -1, done = -1, code = -1, urlCount = -1, keyCount = -1;
    unregister(urls, 1, ^bool(CFArrayRef errors, bool isDone) {
        calls++;
        errorCount = (int) CFArrayGetCount(errors);
        done = isDone;
        if (errorCount == 1) {
            CFErrorRef error = (CFErrorRef) CFArrayGetValueAtIndex(errors, 0);
            CFStringGetCString(CFErrorGetDomain(error), domain, sizeof domain, kCFStringEncodingUTF8);
            code = (int) CFErrorGetCode(error);
            CFArrayAppendValue(urls, font); // the caller's array may change while the handler runs: the error holds a copy
            CFDictionaryRef info = CFErrorCopyUserInfo(error);
            keyCount = (int) CFDictionaryGetCount(info);
            CFStringRef d = CFDictionaryGetValue(info, CFSTR("NSLocalizedDescription"));
            CFStringRef r = CFDictionaryGetValue(info, CFSTR("NSLocalizedFailureReason"));
            CFArrayRef list = CFDictionaryGetValue(info, CFSTR("CTFontManagerErrorFontURLs"));
            if (d) CFStringGetCString(d, description, sizeof description, kCFStringEncodingUTF8);
            if (r) CFStringGetCString(r, reason, sizeof reason, kCFStringEncodingUTF8);
            urlCount = list ? (int) CFArrayGetCount(list) : -1;
            if (list && urlCount == 1) urlCount = CFEqual(CFArrayGetValueAtIndex(list, 0), font) ? 1 : -2;
            CFRelease(info);
        }
        return false;
    });
    EXPECT(calls == 1, "the handler is called once, before the function returns (probe1:90)");
    EXPECT(errorCount == 1 && done == 1, "one error and done true (probe1:89)");
    EXPECT(strcmp(domain, "com.apple.CoreText.CTFontManagerErrorDomain") == 0, "error domain (probe1:89)");
    EXPECT(code == 201, "error code 201 (probe1:89)");
    EXPECT(keyCount == 3, "three user-info entries (probe1:89)");
    EXPECT(strcmp(description, "The file is not registered in the specified scope.") == 0, "NSLocalizedDescription (probe1:89)");
    EXPECT(strcmp(reason, "Font unregistration was unsuccessful.") == 0, "NSLocalizedFailureReason (probe1:89)");
    EXPECT(urlCount == 1, "CTFontManagerErrorFontURLs holds the URL (count 1 is probe1:89; that it is the URL is inferred)");
    CFRelease(urls);
    CFRelease(font);
    printf("PASS: CTFontManager observed behaviour\n");
    return 0;
}
