#import <AppKit/NSColorSampler.h>
#import <AppKit/NSColor.h>

@implementation NSColorSampler

- (void) showSamplerWithSelectionHandler: (void (^)(NSColor *selectedColor)) selectionHandler {
    if (selectionHandler) {
        selectionHandler(nil);
    }
}

@end
