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
