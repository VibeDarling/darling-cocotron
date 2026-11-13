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

#import <AppKit/NSSharingService.h>
#import <AppKit/NSToolbarItem.h>

@class NSSharingServicePickerToolbarItem;

@protocol NSSharingServicePickerToolbarItemDelegate <NSSharingServicePickerDelegate>
// Required: the items to share when the picker is shown.
- (NSArray *) itemsForSharingServicePickerToolbarItem: (NSSharingServicePickerToolbarItem *) pickerToolbarItem;
@end

// A toolbar item that displays the share sheet (macOS 10.15). The delegate supplies the items. Cocotron has
// no share sheet, so activating the item without an application-set target and action aborts with a message.
@interface NSSharingServicePickerToolbarItem : NSToolbarItem {
    id<NSSharingServicePickerToolbarItemDelegate> _delegate;
}

@property (assign) id<NSSharingServicePickerToolbarItemDelegate> delegate;

@end
