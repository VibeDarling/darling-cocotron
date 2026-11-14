#import <QuartzCore/CAFrameRateRange.h>

// Public (macOS 12.0): the documentation says only that it reports whether two frame rate ranges are equal,
// so the three rates are compared exactly, as the struct's own value equality would.
bool CAFrameRateRangeIsEqualToRange(CAFrameRateRange range, CAFrameRateRange other)
{
    return range.minimum == other.minimum && range.maximum == other.maximum && range.preferred == other.preferred;
}
