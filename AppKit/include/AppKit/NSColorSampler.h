#import <Foundation/NSObject.h>

@class NSColor;

@interface NSColorSampler : NSObject

- (void) showSamplerWithSelectionHandler: (void (^)(NSColor *selectedColor)) selectionHandler;

@end
