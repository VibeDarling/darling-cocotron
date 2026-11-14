/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <QuartzCore/CATiledLayer.h>

// The defaults are the documented ones: a 256 by 256 tile, one level of detail, no bias, and a fade of a quarter
// of a second.
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
