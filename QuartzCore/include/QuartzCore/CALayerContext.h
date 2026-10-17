#import <CoreGraphics/CGGeometry.h>
#import <Foundation/NSObject.h>
#import <OpenGL/OpenGL.h>
#import <CoreGraphics/CGSubWindow.h>

@class CARenderer, CALayer, CGLPixelSurface, NSTimer, NSMutableArray, NSNumber;

@interface CALayerContext : NSObject {
    CGRect _frame;
    CGLPixelFormatObj _pixelFormat;
    CGLContextObj _glContext;
    CALayer *_layer;
    CARenderer *_renderer;

    NSMutableArray *_deleteTextureIds;

    NSTimer *_timer;
    CGSubWindow* _subwindow;
    void* _cglWindow;
    BOOL _rendered;
    BOOL _renderRequested;
    BOOL _renderInProgress;
}

@property(readonly) CGLContextObj glContext;

- initWithFrame: (CGRect) rect;

- (void) setFrame: (CGRect) value;
- (void) setLayer: (CALayer *) layer;
- (void) setHidden: (BOOL) hidden;
- (void) setSubwindow: (CGSubWindow*) subwindow;

- (void) invalidate;

- (void) render;

// Composites and presents now, for a caller on the main thread that is waiting for the
// drawables a pass hands back. Returns NO, doing nothing, off the main thread or while a
// pass is already running.
- (BOOL) renderPendingPresents;

- (void) startTimerIfNeeded;

- (void) deleteTextureId: (NSNumber *) textureId;

- (void) flush;

@end
