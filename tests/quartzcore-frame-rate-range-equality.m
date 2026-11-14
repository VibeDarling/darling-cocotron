#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CAFrameRateRangeIsEqualToRange (CAFrameRateRange.h, macOS 12.0): two ranges are equal when the minimum, the
// maximum and the preferred rate all match. Each field is varied on its own so that a comparison that skips one
// is caught.
int main(void) {
    CAFrameRateRange base = {30, 120, 60};
    CAFrameRateRange same = {30, 120, 60};
    EXPECT(CAFrameRateRangeIsEqualToRange(base, same), "identical ranges are equal");
    EXPECT(CAFrameRateRangeIsEqualToRange(base, base), "a range equals itself");
    CAFrameRateRange differentMinimum = {24, 120, 60};
    CAFrameRateRange differentMaximum = {30, 90, 60};
    CAFrameRateRange differentPreferred = {30, 120, 90};
    EXPECT(!CAFrameRateRangeIsEqualToRange(base, differentMinimum), "a different minimum differs");
    EXPECT(!CAFrameRateRangeIsEqualToRange(base, differentMaximum), "a different maximum differs");
    EXPECT(!CAFrameRateRangeIsEqualToRange(base, differentPreferred), "a different preferred rate differs");
    EXPECT(!CAFrameRateRangeIsEqualToRange(differentPreferred, base), "the comparison is symmetric");
    CAFrameRateRange zero = {0, 0, 0};
    EXPECT(CAFrameRateRangeIsEqualToRange(zero, (CAFrameRateRange){0, 0, 0}), "the zero range equals itself");
    printf("PASS: CAFrameRateRangeIsEqualToRange\n");
    return 0;
}
