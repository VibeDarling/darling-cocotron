/*
 This file is part of Darling.

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

#import <AppKit/NSSharingServicePickerToolbarItem.h>
#include <stdio.h>
#include <stdlib.h>

@implementation NSSharingServicePickerToolbarItem

@synthesize delegate = _delegate;

// The share sheet is the item's own action unless the application gave it another target and action. Answering
// from the accessors, not from init, covers items decoded from a nib and copies of an item.
- target {
    return [super target] != nil ? [super target] : self;
}

- (SEL) action {
    return [super action] != NULL ? [super action] : @selector(_showSharingServicePicker:);
}

- (void) _showSharingServicePicker: (id) sender {
    fprintf(stderr, "AppKit: NSSharingServicePickerToolbarItem cannot show the share sheet: it is not implemented\n");
    abort();
}

@end
