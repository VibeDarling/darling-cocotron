#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <objc/runtime.h>

// QuartzCore must bind against any Metal that exports the public API. Darling's own
// Metal also exports the private class MTLTextureInternal, which a Metal served from
// a macOS dyld shared cache does not, so QuartzCore may only look that class up.
//
//   quartzcore-foreign-metal foreign   Metal without MTLTextureInternal (see the .md)
//   quartzcore-foreign-metal darling   Darling's Metal: the looked-up name must exist

#define CHECK(cond, ...) do { if (!(cond)) { printf("FAIL: "); printf(__VA_ARGS__); printf("\n"); return 1; } } while (0)

int main(int argc, char **argv) {
    @autoreleasepool {
        CHECK(argc == 2 && (!strcmp(argv[1], "foreign") || !strcmp(argv[1], "darling")), "usage: %s foreign|darling", argv[0]);
        BOOL foreign = !strcmp(argv[1], "foreign");

        void *quartzCore = dlopen("/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore", RTLD_NOW);
        if (quartzCore == NULL) {
            const char *error = dlerror();
            CHECK(strstr(error, "Symbol not found: _OBJC_CLASS_$_MTLTextureInternal") == NULL,
                  "QuartzCore imports MTLTextureInternal from Metal: %s", error);
            CHECK(0, "QuartzCore does not load, for a reason other than MTLTextureInternal: %s", error);
        }
        CHECK(objc_getClass("CAMetalLayer") != Nil, "QuartzCore loaded but CAMetalLayer is missing");

        Class texture = objc_getClass("MTLTextureInternal");
        if (foreign) {
            CHECK(texture == Nil, "this Metal defines MTLTextureInternal, so it is not a foreign Metal");
        } else {
            CHECK(texture != Nil, "Darling's Metal no longer defines MTLTextureInternal, which QuartzCore looks up by name");
        }
        printf("PASS: QuartzCore with %s Metal\n", argv[1]);
    }
    return 0;
}
