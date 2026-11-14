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

#import <Foundation/Foundation.h>
#import <QuartzCore/CALayer.h>

// Private QuartzCore names that stock applications import at launch (Freeform, Photos, Podcasts, Journal, Mail,
// FindMy). The public documentation has neither their types nor their values. GUESS for every one: an NSString
// constant, whose value is the name without its kCA prefix (kCAContentsFormat... follows the neighbouring
// contents formats and drops the whole prefix), with a lower case first letter except for the contents format.
// Nothing in Cocotron reads them.

NSString *const kCAAnimationAbsolute = @"absolute";
NSString *const kCASnapshotBottomLeftOrigin = @"snapshotBottomLeftOrigin";
NSString *const kCASnapshotContextId = @"snapshotContextId";
NSString *const kCASnapshotDestination = @"snapshotDestination";
NSString *const kCASnapshotDisplayName = @"snapshotDisplayName";
NSString *const kCASnapshotIgnoreRootAccessibilityFilters = @"snapshotIgnoreRootAccessibilityFilters";
NSString *const kCASnapshotLayerId = @"snapshotLayerId";
NSString *const kCASnapshotMode = @"snapshotMode";
NSString *const kCASnapshotModeLayer = @"snapshotModeLayer";
NSString *const kCASnapshotReuseBackdropContents = @"snapshotReuseBackdropContents";
NSString *const kCASnapshotTransform = @"snapshotTransform";
NSString *const kCAContextIgnoresHitTest = @"contextIgnoresHitTest";
NSString *const kCAContextDisplayName = @"contextDisplayName";
NSString *const kCAPackageTypeArchive = @"archive";
NSString *const kCAContentsScalingRepeat = @"repeat";
NSString *const kCAContentsFormatRGBA8ColorRGBA8LinearGlyphMask = @"RGBA8ColorRGBA8LinearGlyphMask";

// Private layer class (Podcasts). GUESS: a plain CALayer subclass that adds nothing of its own.
@interface CAPortalLayer : CALayer
@end

@implementation CAPortalLayer
@end
