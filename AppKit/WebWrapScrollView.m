#import <AppKit/NSScrollView.h>

// WebKit-internal scroll view that Dictionary.app's DescriptionView.nib names directly.
// Nothing in the tree defines it: the guest WebKit framework is built from pyobjc, which
// only wraps public headers, and WebWrapScrollView is not public API. Without the class the
// nib cannot be unarchived and Dictionary shows no window at all.
//
// "Pocket edges" is the rubber-band overscroll affordance. NSScrollView here does not draw
// it, so that value is only kept so callers can read back what they set.
@interface WebWrapScrollView : NSScrollView {
	NSInteger _allowedPocketEdges;
	id _webView;
}
- (void) setAllowedPocketEdges: (NSInteger) allowedPocketEdges;
- (NSInteger) allowedPocketEdges;
- (void) setupWebView: (id) webView;
- (id) webView;
@end

@implementation WebWrapScrollView

- (void) setAllowedPocketEdges: (NSInteger) allowedPocketEdges {
	_allowedPocketEdges = allowedPocketEdges;
}

- (NSInteger) allowedPocketEdges {
	return _allowedPocketEdges;
}

// Dictionary hands over the WKWebView it built and expects this scroll view to host it.
// With no working WebKit in the tree the object arriving here is usually nil, so this only
// has to carry the wiring: keep the reference and, when it really is a view, scroll it.
- (void) setupWebView: (id) webView {
	_webView = webView;
	if ([webView isKindOfClass: [NSView class]])
		[self setDocumentView: webView];
}

- (id) webView {
	return _webView;
}

@end
