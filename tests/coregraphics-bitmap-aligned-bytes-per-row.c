#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGBitmapGetAlignedBytesPerRow is private (no SDK header), so the test finds it through dlsym; Maps binds it at
// launch. The pairs below were observed on a real Mac (macOS 26.1) with a program of our own that called the
// function (mac-probe/darling_probe3.txt Part 2): a row length rounds up to a multiple of 32, and 0 stays 0.
// Also checked from the public CGBitmapContextCreate documentation: a bitmap context accepts the result as
// bytesPerRow (it must be at least width * bytes per pixel). The overflow abort is our own choice (no source).
int main(void) {
    size_t (*align)(size_t) = (size_t (*)(size_t)) dlsym(RTLD_DEFAULT, "CGBitmapGetAlignedBytesPerRow");
    EXPECT(align != NULL, "CGBitmapGetAlignedBytesPerRow is exported");

    for (size_t length = 0; length < 5000; length++)
        EXPECT(align(length) >= length, "the aligned length is never smaller than the length");

    static const size_t observed[][2] = {
        {0, 0}, {1, 32}, {2, 32}, {3, 32}, {4, 32}, {7, 32}, {8, 32}, {15, 32}, {16, 32}, {17, 32}, {31, 32},
        {32, 32}, {33, 64}, {48, 64}, {63, 64}, {64, 64}, {65, 96}, {100, 128}, {127, 128}, {128, 128},
        {129, 160}, {255, 256}, {256, 256}, {257, 288}, {400, 416}, {511, 512}, {512, 512}, {513, 544},
        {1000, 1024}, {1023, 1024}, {1024, 1024}, {1025, 1056}, {4095, 4096}, {4096, 4096}, {4097, 4128},
        {10000, 10016} };
    for (size_t i = 0; i < sizeof observed / sizeof observed[0]; i++)
        EXPECT(align(observed[i][0]) == observed[i][1], "aligned length differs from the real-Mac observation");

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    size_t bytesPerRow = align(100 * 4);
    CGContextRef context = CGBitmapContextCreate(NULL, 100, 10, 8, bytesPerRow, space, kCGImageAlphaPremultipliedLast);
    EXPECT(context != NULL, "a bitmap context accepts the aligned bytesPerRow");
    EXPECT(CGBitmapContextGetBytesPerRow(context) == bytesPerRow, "the context keeps the aligned bytesPerRow");
    CGContextRelease(context);
    CGColorSpaceRelease(space);

    // A length that cannot be rounded up without wrapping aborts instead of returning a smaller length.
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        freopen("/dev/null", "w", stderr);
        align(SIZE_MAX);
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    EXPECT(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, "an unrepresentable length aborts");

    printf("PASS: CGBitmapGetAlignedBytesPerRow\n");
    return 0;
}
