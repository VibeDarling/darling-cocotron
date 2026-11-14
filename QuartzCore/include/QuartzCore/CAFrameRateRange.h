#ifndef CAFRAMERATERANGE_H
#define CAFRAMERATERANGE_H

#include <stdbool.h>
#import <QuartzCore/CABase.h>

// The frame rate range type (macOS 12). The three-float layout is ABI: callers built against the macOS SDK pass it
// by value, and Swift mangles it as So16CAFrameRateRangeV.
typedef struct CAFrameRateRange {
    float minimum;
    float maximum;
    float preferred;
} CAFrameRateRange;

// Whether two ranges have the same minimum, maximum and preferred rates (macOS 12.0, CAFrameRateRange.h).
CA_EXTERN bool CAFrameRateRangeIsEqualToRange(CAFrameRateRange range, CAFrameRateRange other);

#endif
