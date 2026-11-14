#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

// CGFloatIsValid is private (no SDK header); Maps binds it at launch, so the test finds it through dlsym. The
// expected results are what the real function returned on macOS 26.1 for each input, read from the 32-bit return
// register (observed with our own client program, quoted in the pull request): 1 for every finite value, 0 for
// NaN and both infinities.
int main(void) {
    uint32_t (*isValid)(double) = (uint32_t (*)(double)) dlsym(RTLD_DEFAULT, "CGFloatIsValid");
    if (isValid == NULL) { printf("FAIL: CGFloatIsValid is exported\n"); return 1; }

    static const struct { const char *name; double value; uint32_t expected; } cases[] = {
        {"0", 0.0, 1}, {"-0", -0.0, 1}, {"1", 1.0, 1}, {"-1", -1.0, 1}, {"0.5", 0.5, 1}, {"1e-320 (subnormal)", 1e-320, 1},
        {"DBL_MIN", DBL_MIN, 1}, {"DBL_MAX", DBL_MAX, 1}, {"-DBL_MAX", -DBL_MAX, 1}, {"1e300", 1e300, 1},
        {"FLT_MAX", (double) FLT_MAX, 1}, {"FLT_MAX*2", (double) FLT_MAX * 2, 1},
        {"NaN", NAN, 0}, {"-NaN", -NAN, 0}, {"+inf", INFINITY, 0}, {"-inf", -INFINITY, 0},
    };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        uint32_t got = isValid(cases[i].value);
        if (got != cases[i].expected) {
            printf("FAIL: CGFloatIsValid(%s) returned %u, expected %u\n", cases[i].name, got, cases[i].expected);
            return 1;
        }
    }
    printf("PASS: CGFloatIsValid\n");
    return 0;
}
