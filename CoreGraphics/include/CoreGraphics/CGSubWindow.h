#ifdef __OBJC__

#import <CoreGraphics/CGGeometry.h>
#import <Foundation/Foundation.h>

@interface CGSubWindow : NSObject

- (void *) nativeWindow;

// Physical drawable pixels per logical point (1 for unscaled backends).
- (CGFloat) backingScaleFactor;

// Present after a successful drawable swap, on the window/UI thread.
- (void) flush;
- (BOOL) requiresMainThreadPresentation;

- (void) show;
- (void) hide;

- (void) setFrame: (CGRect) frame;

@end

#endif
