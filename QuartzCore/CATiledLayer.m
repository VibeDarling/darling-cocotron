#import <QuartzCore/CATiledLayer.h>

// The defaults are the ones Apple documents (CATiledLayer: tileSize (256.0, 256.0), levelsOfDetail 1,
// levelsOfDetailBias 0, +fadeDuration 0.25 seconds; types CGSize, size_t, size_t, CFTimeInterval) and the ones a real
// Mac printed, with the setters round-tripping (macOS 26.1, probe 11 section 2, darling_probe11.txt lines 45-46).
static const CGFloat kDefaultTileSide = 256;
static const CFTimeInterval kDefaultFadeDuration = 0.25;

@implementation CATiledLayer

@synthesize levelsOfDetail = _levelsOfDetail;
@synthesize levelsOfDetailBias = _levelsOfDetailBias;
@synthesize tileSize = _tileSize;

+ (CFTimeInterval) fadeDuration {
    return kDefaultFadeDuration;
}

- (void) _setTiledDefaults {
    _levelsOfDetail = 1;
    _levelsOfDetailBias = 0;
    _tileSize = CGSizeMake(kDefaultTileSide, kDefaultTileSide);
}

- init {
    self = [super init];
    if (self != nil)
        [self _setTiledDefaults];
    return self;
}

- initWithLayer: (id) layer {
    self = [super initWithLayer: layer];
    if (self == nil)
        return nil;
    [self _setTiledDefaults];
    if ([layer isKindOfClass: [CATiledLayer class]]) {
        CATiledLayer *other = layer;
        _levelsOfDetail = other->_levelsOfDetail;
        _levelsOfDetailBias = other->_levelsOfDetailBias;
        _tileSize = other->_tileSize;
    }
    return self;
}

// The archive keys below are made up: neither the public documentation nor the probes say how a real CATiledLayer
// archives these four properties (GUESS), so an archive made here is not claimed to match Apple's.
- (void) encodeWithCoder: (NSCoder *) coder {
    [super encodeWithCoder: coder];
    [coder encodeInt64: (int64_t) _levelsOfDetail forKey: @"levelsOfDetail"];
    [coder encodeInt64: (int64_t) _levelsOfDetailBias forKey: @"levelsOfDetailBias"];
    [coder encodeDouble: _tileSize.width forKey: @"tileSizeWidth"];
    [coder encodeDouble: _tileSize.height forKey: @"tileSizeHeight"];
}

- initWithCoder: (NSCoder *) coder {
    self = [super initWithCoder: coder];
    if (self == nil)
        return nil;
    [self _setTiledDefaults];
    if ([coder containsValueForKey: @"levelsOfDetail"])
        _levelsOfDetail = (size_t) [coder decodeInt64ForKey: @"levelsOfDetail"];
    if ([coder containsValueForKey: @"levelsOfDetailBias"])
        _levelsOfDetailBias = (size_t) [coder decodeInt64ForKey: @"levelsOfDetailBias"];
    if ([coder containsValueForKey: @"tileSizeWidth"] && [coder containsValueForKey: @"tileSizeHeight"])
        _tileSize = CGSizeMake([coder decodeDoubleForKey: @"tileSizeWidth"],
                               [coder decodeDoubleForKey: @"tileSizeHeight"]);
    return self;
}

@end
