#import <AppKit/NSStringDrawing.h>

@implementation NSStringDrawingContext

@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize minimumTrackingAdjustment = _minimumTrackingAdjustment;
@synthesize actualScaleFactor = _actualScaleFactor;
@synthesize actualTrackingAdjustment = _actualTrackingAdjustment;
@synthesize totalBounds = _totalBounds;

// Initial values: no minimum scale factor and no minimum tracking adjustment (both 0, no limit), an actual
// scale factor of 1.0 (the "no scaling" value of a scale factor, documented), and no tracking adjustment
// and empty total bounds until something is drawn. GUESS: the documentation states no initial values for
// the zero fields.
- (instancetype) init {
    if ((self = [super init]) != nil) {
        _actualScaleFactor = 1.0;
    }
    return self;
}

- (void) _setTotalBounds: (NSRect) bounds {
    _totalBounds = bounds;
}

@end
