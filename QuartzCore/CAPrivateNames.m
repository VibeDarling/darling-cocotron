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
// FindMy). Each is an NSString constant with the value a real Mac printed (macOS 26.1, probe 12 section 1,
// darling_probe12.txt lines 3-18). The values are not derived from the names: kCASnapshotMode is "mode",
// kCASnapshotIgnoreRootAccessibilityFilters is "ignoreAccessibility", kCAPackageTypeArchive is
// "com.apple.coreanimation-archive". Nothing in Cocotron reads them.

NSString *const kCAAnimationAbsolute = @"absolute";
NSString *const kCASnapshotBottomLeftOrigin = @"bottomLeftOrigin";
NSString *const kCASnapshotContextId = @"contextId";
NSString *const kCASnapshotDestination = @"destination";
NSString *const kCASnapshotDisplayName = @"displayName";
NSString *const kCASnapshotIgnoreRootAccessibilityFilters = @"ignoreAccessibility";
NSString *const kCASnapshotLayerId = @"layerId";
NSString *const kCASnapshotMode = @"mode";
NSString *const kCASnapshotModeLayer = @"modeLayer";
NSString *const kCASnapshotReuseBackdropContents = @"reuseBackdrops";
NSString *const kCASnapshotTransform = @"transform";
NSString *const kCAContextIgnoresHitTest = @"ignoresHitTest";
NSString *const kCAContextDisplayName = @"displayName";
NSString *const kCAPackageTypeArchive = @"com.apple.coreanimation-archive";
NSString *const kCAContentsScalingRepeat = @"repeat";
NSString *const kCAContentsFormatRGBA8ColorRGBA8LinearGlyphMask = @"RGBA8ColorRGBA8Mask";

// Private layer class (Podcasts). It exists on the real Mac (probe 12, darling_probe12.txt line 21); its superclass
// and interface were not observed, so GUESS: a plain CALayer subclass that adds nothing of its own.
@interface CAPortalLayer : CALayer
@end

@implementation CAPortalLayer
@end
