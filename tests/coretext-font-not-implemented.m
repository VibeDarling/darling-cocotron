// Links CoreText without AppKit. CTFont functions that Cocotron does not implement stop by name instead of answering
// with a placeholder that looks like an answer.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void checkAborts(const char *name)
{
    void (*function)(void) = (void (*)(void))dlsym(RTLD_DEFAULT, name);
    expect(function != NULL, [NSString stringWithFormat:@"%s is defined", name]);

    int pipefd[2];
    expect(pipe(pipefd) == 0, @"pipe");
    pid_t child = fork();
    if (child == 0)
    {
        dup2(pipefd[1], 2);
        close(pipefd[0]);
        function();
        _exit(0);
    }
    close(pipefd[1]);
    char message[256] = {0};
    ssize_t count = read(pipefd[0], message, sizeof(message) - 1);
    int status = 0;
    waitpid(child, &status, 0);
    expect(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, [NSString stringWithFormat:@"%s aborts", name]);
    expect(count > 0 && strstr(message, name) != NULL, [NSString stringWithFormat:@"%s names itself", name]);
}

int main(void)
{
    @autoreleasepool
    {
        // Functions that used to print STUB and return a placeholder stop by name.
        static const char *const names[] = {
            "CTFontCopyDefaultCascadeListForLanguages",
            "CTFontGetStringEncoding", "CTFontCopySupportedLanguages", "CTFontCopyFeatures", "CTFontCopyFeatureSettings",
            "CTFontGetPlatformFont", "CTFontCreateWithPlatformFont",
            "CTFontCreateWithQuickdrawInstance",
        };
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++)
            checkAborts(names[i]);

        // The documented "none" answers stay answers: no font with those traits or in that family, no ligature carets.
        CTFontRef plain = CTFontCreateWithName(CFSTR("DejaVu Sans"), 20, NULL);
        expect(CTFontCreateCopyWithSymbolicTraits(plain, 20, NULL, kCTFontTraitBold, kCTFontTraitBold) == NULL, @"no bold variant is looked up");
        expect(CTFontCreateCopyWithFamily(plain, 20, NULL, CFSTR("DejaVu Serif")) == NULL, @"no family is looked up");
        CGFloat carets[2];
        expect(CTFontGetLigatureCaretPositions(plain, 3, carets, 2) == 0, @"no ligature carets");
        CFRelease(plain);

        // A face without variation axes has none: the documented answer is NULL, not a stop.
        CTFontRef font = CTFontCreateWithName(CFSTR("DejaVu Sans"), 20, NULL);
        expect(font != NULL, @"a font");
        expect(CTFontCopyVariationAxes(font) == NULL && CTFontCopyVariation(font) == NULL, @"no variation axes on a fixed face");
        CFRelease(font);
        NSLog(@"coretext-font-not-implemented: ok");
    }
    return 0;
}
