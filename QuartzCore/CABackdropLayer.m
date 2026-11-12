/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import <QuartzCore/CALayer.h>

/* QuartzCore's private backdrop layer, which apps make by name (variable blur views) and
 * configure with filters. The window server blurs what is behind it on Apple's platforms;
 * Darling has no compositor to do that, so the backdrop shows through unchanged. */
@interface CABackdropLayer : CALayer
@end

@implementation CABackdropLayer
@end
