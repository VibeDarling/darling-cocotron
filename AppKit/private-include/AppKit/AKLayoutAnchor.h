/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/NSString.h>

// A new anchor of the named Foundation class, or of NSLayoutAnchor when that subclass is
// missing. Returns nil, after one log line per process, when Foundation cannot create anchors.
// AppKit-private: not exported from AppKit.
__attribute__((visibility("hidden"))) extern id
AKLayoutAnchorForItem(id item, NSString *className, NSLayoutAttribute attribute);
