#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CAFrameRateRangeMake (CAFrameRateRange.h, macOS 12.0) takes minimum, maximum and preferred, in the order of
// the struct's fields. Three different values per call show that no argument lands in the wrong field. The
// function is looked up with dlsym, so that the exported symbol is the one called (not an inlined copy) and
// a library without it fails this test instead of stopping the process at load.
int main(void) {
    CAFrameRateRange (*make)(float, float, float) = (CAFrameRateRange (*)(float, float, float)) dlsym(RTLD_DEFAULT, "CAFrameRateRangeMake");
    EXPECT(make != NULL, "CAFrameRateRangeMake is exported");
    CAFrameRateRange range = make(24, 120, 60);
    EXPECT(range.minimum == 24, "minimum");
    EXPECT(range.maximum == 120, "maximum");
    EXPECT(range.preferred == 60, "preferred");
    CAFrameRateRange other = make(10, 30, 15);
    EXPECT(other.minimum == 10 && other.maximum == 30 && other.preferred == 15, "a second call is independent of the first");
    EXPECT(range.minimum == 24 && range.maximum == 120 && range.preferred == 60, "the first result is unchanged");
    CAFrameRateRange unordered = make(60, 30, 0);
    EXPECT(unordered.minimum == 60 && unordered.maximum == 30 && unordered.preferred == 0, "the values are stored as given");
    printf("PASS: CAFrameRateRangeMake\n");
    return 0;
}
