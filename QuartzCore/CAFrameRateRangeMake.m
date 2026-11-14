#import <QuartzCore/CAFrameRateRange.h>

// Public (macOS 12.0): Apple's documentation gives only the prototype, with the arguments in the order of the
// struct's fields, so the three rates are stored as given, with no clamping or reordering.
CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred)
{
    return (CAFrameRateRange){minimum, maximum, preferred};
}
