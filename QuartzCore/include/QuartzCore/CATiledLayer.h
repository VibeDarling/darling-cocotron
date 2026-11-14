#import <QuartzCore/CALayer.h>

// Public (QuartzCore/CATiledLayer.h). The layer keeps the four documented properties and is otherwise a plain
// CALayer: it asks -drawInContext: for the whole layer in one piece instead of tile by tile, and it never fades
// tiles in, so the properties are stored for clients and not yet acted on.
@interface CATiledLayer : CALayer {
    size_t _levelsOfDetail;
    size_t _levelsOfDetailBias;
    CGSize _tileSize;
}

+ (CFTimeInterval) fadeDuration;

@property size_t levelsOfDetail;
@property size_t levelsOfDetailBias;
@property CGSize tileSize;

@end
