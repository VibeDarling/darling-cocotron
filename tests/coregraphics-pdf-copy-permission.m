#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        bool (*allowsCopying)(CGPDFDocumentRef) = dlsym(RTLD_DEFAULT, "CGPDFDocumentAllowsCopying");
        if (!allowsCopying) {
            fputs("missing PDF copy-permission export\n", stderr);
            return 10;
        }
        const char *names[] = {"plain", "direct-null", "indirect-null", "undefined-reference",
                               "encrypted-restricted", "encrypted-permitted",
                               "wrong-type"};
        for (unsigned i = 0; i < 7; i++) {
            NSString *path = [NSString stringWithFormat:@"%s/%s.pdf", argv[1], names[i]];
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (!data) return 20 + i;
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
            CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
            CGDataProviderRelease(provider);
            if (!document) return 30 + i;
            if (allowsCopying(document) != (i < 4)) {
                fprintf(stderr, "unexpected copy permission for %s\n", names[i]);
                return 40 + i;
            }
            CGPDFDocumentRelease(document);
        }
        if (allowsCopying(NULL)) return 50;
        puts("parsed PDF copy-permission checks passed");
    }
    return 0;
}
