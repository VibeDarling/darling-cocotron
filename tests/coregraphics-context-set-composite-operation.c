#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, ...) do { if (!(cond)) { printf("FAIL: "); printf(__VA_ARGS__); printf("\n"); return 1; } } while (0)

// CGContextSetCompositeOperation and CGContextGetCompositeOperation are private (no SDK header); Maps binds them at
// launch, so the test finds them through dlsym. Every expectation below was observed on macOS 26.1 with our own
// client program: a 1x1 premultiplied RGBA bitmap, destination blue at alpha 0.25 drawn first, then the operation
// set, then red at alpha 0.75 drawn over it; the four bytes are the resulting pixel. The probe is quoted in the pull
// request body.
static const unsigned char pixels[28][4] = {
    {0, 0, 0, 0}, {191, 0, 0, 191}, {191, 0, 16, 207}, {48, 0, 0, 48}, {143, 0, 0, 143}, {48, 0, 16, 64},
    {143, 0, 64, 207}, {0, 0, 48, 48}, {0, 0, 16, 16}, {143, 0, 48, 191}, {143, 0, 16, 159}, {191, 0, 64, 255},
    {191, 0, 64, 255}, {143, 0, 16, 207}, {191, 0, 64, 207}, {143, 0, 64, 207}, {143, 0, 16, 207},
    {191, 0, 64, 207}, {143, 0, 64, 207}, {143, 0, 64, 207}, {143, 0, 64, 207}, {191, 0, 16, 207},
    {191, 0, 64, 207}, {191, 0, 64, 207}, {160, 0, 16, 207}, {143, 0, 64, 207}, {160, 0, 16, 207},
    {153, 10, 64, 207},
};

// The public CGBlendMode and the operation number the getter reported after CGContextSetBlendMode (observed on
// the same Mac). By name: Cocotron's header lists HardLight before SoftLight, the SDK's order is the other way round.
static const struct { CGBlendMode mode; int operation; } blendModes[] = {
    {kCGBlendModeNormal, 2}, {kCGBlendModeMultiply, 13}, {kCGBlendModeScreen, 14}, {kCGBlendModeOverlay, 15},
    {kCGBlendModeDarken, 16}, {kCGBlendModeLighten, 17}, {kCGBlendModeColorDodge, 18}, {kCGBlendModeColorBurn, 19},
    {kCGBlendModeSoftLight, 20}, {kCGBlendModeHardLight, 21}, {kCGBlendModeDifference, 22}, {kCGBlendModeExclusion, 23},
    {kCGBlendModeHue, 24}, {kCGBlendModeSaturation, 25}, {kCGBlendModeColor, 26}, {kCGBlendModeLuminosity, 27},
    {kCGBlendModeClear, 0}, {kCGBlendModeCopy, 1}, {kCGBlendModeSourceIn, 3}, {kCGBlendModeSourceOut, 4},
    {kCGBlendModeSourceAtop, 5}, {kCGBlendModeDestinationOver, 6}, {kCGBlendModeDestinationIn, 7},
    {kCGBlendModeDestinationOut, 8}, {kCGBlendModeDestinationAtop, 9}, {kCGBlendModeXOR, 10},
    {kCGBlendModePlusDarker, 11}, {kCGBlendModePlusLighter, 12},
};

// Cocotron's own blend engine draws a different pixel than the Mac for these operations, with the public blend
// mode of the same name as well (an existing Onyx2D gap, not this function's): plus darker, overlay, color dodge,
// color burn, soft light, hard light, hue, saturation, color and luminosity. For them the test asserts that the
// operation draws what the public blend mode draws in the same engine, not the Mac's bytes.
static const int engineGap[] = { 11, 15, 18, 19, 20, 21, 24, 25, 26, 27 };

static void (*setOperation)(CGContextRef, int);
static int (*getOperation)(CGContextRef);

static CGContextRef make(unsigned char pixel[4]) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    memset(pixel, 0, 4);
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    return context;
}

// dest = 1: blue at alpha 0.25 (the destination); dest = 0: red at alpha 0.75 (the source).
static void fill(CGContextRef context, int dest) {
    CGContextSetRGBFillColor(context, dest ? 0 : 1, 0, dest ? 1 : 0, dest ? 0.25 : 0.75);
    CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
}

// Runs the call in a child with stderr piped; returns the message, and whether it died of SIGABRT.
static int dies(int kind, int value, char message[256]) {
    int fds[2];
    if (pipe(fds) != 0) return -1;
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        dup2(fds[1], STDERR_FILENO);
        close(fds[0]); close(fds[1]);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        unsigned char pixel[4];
        CGContextRef context = (kind == 2 || kind == 3) ? NULL : make(pixel);
        if (kind == 0 || kind == 2) setOperation(context, value);
        else if (kind == 4) { CGContextSetBlendMode(context, (CGBlendMode) value); getOperation(context); }
        else getOperation(context);
        _exit(0);
    }
    close(fds[1]);
    size_t length = 0;
    memset(message, 0, 256);
    for (;;) {
        ssize_t got = read(fds[0], message + length, 255 - length);
        if (got <= 0) break;
        length += (size_t) got;
    }
    close(fds[0]);
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT;
}

int main(void) {
    setOperation = (void (*)(CGContextRef, int)) dlsym(RTLD_DEFAULT, "CGContextSetCompositeOperation");
    getOperation = (int (*)(CGContextRef)) dlsym(RTLD_DEFAULT, "CGContextGetCompositeOperation");
    EXPECT(setOperation != NULL, "CGContextSetCompositeOperation is exported");
    EXPECT(getOperation != NULL, "CGContextGetCompositeOperation is exported");

    for (int operation = 0; operation < 28; operation++) {
        unsigned char pixel[4];
        CGContextRef context = make(pixel);
        fill(context, 1);
        setOperation(context, operation);
        EXPECT(getOperation(context) == operation, "operation %d: the getter reports %d", operation, getOperation(context));
        fill(context, 0);
        CGContextRelease(context);

        int gap = 0;
        for (size_t i = 0; i < sizeof engineGap / sizeof engineGap[0]; i++) gap |= engineGap[i] == operation;
        unsigned char want[4];
        if (!gap) {
            memcpy(want, pixels[operation], 4);
        } else {
            CGBlendMode mode = kCGBlendModeNormal;
            for (size_t i = 0; i < sizeof blendModes / sizeof blendModes[0]; i++)
                if (blendModes[i].operation == operation) mode = blendModes[i].mode;
            CGContextRef reference = make(want);
            fill(reference, 1);
            CGContextSetBlendMode(reference, mode);
            fill(reference, 0);
            CGContextRelease(reference);
        }
        EXPECT(memcmp(pixel, want, 4) == 0, "operation %d: pixel %d %d %d %d, expected %d %d %d %d%s", operation, pixel[0],
               pixel[1], pixel[2], pixel[3], want[0], want[1], want[2], want[3], gap ? " (the public blend mode's pixel)" : " (observed)");
    }

    unsigned char pixel[4];
    CGContextRef context = make(pixel);
    EXPECT(getOperation(context) == 2, "a new context reports source over (2), got %d", getOperation(context));
    for (size_t i = 0; i < sizeof blendModes / sizeof blendModes[0]; i++) {
        CGContextSetBlendMode(context, blendModes[i].mode);
        EXPECT(getOperation(context) == blendModes[i].operation, "blend mode %d reports operation %d, expected %d",
               (int) blendModes[i].mode, getOperation(context), blendModes[i].operation);
    }
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSaveGState(context);
    setOperation(context, 1);
    EXPECT(getOperation(context) == 1, "operation 1 inside a saved state");
    CGContextRestoreGState(context);
    EXPECT(getOperation(context) == 2, "restoring the state brings the saved operation back, got %d", getOperation(context));
    setOperation(context, 1);
    CGContextSetBlendMode(context, kCGBlendModeMultiply);
    EXPECT(getOperation(context) == 13, "a later blend mode replaces the operation");
    CGContextRelease(context);

    // The Mac crashes on these (SIGSEGV); we abort with a message that names the function.
    char message[256];
    static const int bad[] = { 28, 29, 1000, -1 };
    for (size_t i = 0; i < sizeof bad / sizeof bad[0]; i++) {
        EXPECT(dies(0, bad[i], message) == 1, "operation %d aborts", bad[i]);
        EXPECT(strstr(message, "CGContextSetCompositeOperation") != NULL, "the message for %d names the setter", bad[i]);
        EXPECT(strstr(message, "the Mac crashes here") != NULL, "the message for %d says the Mac crashes", bad[i]);
    }
    EXPECT(dies(2, 2, message) == 1, "the setter aborts for a NULL context");
    EXPECT(strstr(message, "NULL context") != NULL, "the setter's message names the NULL context");
    EXPECT(strstr(message, "the Mac crashes here") != NULL, "the setter's NULL message says the Mac crashes");
    EXPECT(dies(3, 0, message) == 1, "the getter aborts for a NULL context");
    EXPECT(strstr(message, "CGContextGetCompositeOperation") != NULL, "the getter's message names the getter");
    EXPECT(strstr(message, "GUESS") != NULL && strstr(message, "the Mac crashes here") == NULL,
           "the getter's NULL message says it is a guess, not an observation");
    // GUESS, NEEDS-REAL-MAC: a blend mode outside 0..27 (reachable by a cast) has no operation number; we abort.
    EXPECT(dies(4, 28, message) == 1, "the getter aborts for blend mode 28");
    EXPECT(strstr(message, "blend mode without an operation") != NULL && strstr(message, "GUESS") != NULL,
           "the message for blend mode 28 says it is a guess");

    printf("PASS: CGContextSetCompositeOperation, CGContextGetCompositeOperation\n");
    return 0;
}
