/*
 This file is part of Darling.

 Copyright (C) 2026 Darling developers

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

// The methods macOS declares for NSLayoutManager in AppKit's NSTextViewSupport category. NSLayoutManager itself comes from
// UIFoundation, which cannot reach NSTextView, NSWindow or the ruler, so AppKit adds these as a category, with the layout
// manager's public API only: they then exist whichever UIFoundation serves the class.

#import <AppKit/NSLayoutManager.h>
#import <AppKit/NSParagraphStyle.h>
#import <AppKit/NSRulerView.h>
#import <AppKit/NSTextContainer.h>
#import <AppKit/NSTextTab.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSWindow.h>
#import "NSRulerMarker+NSTextExtensions.h"

@implementation NSLayoutManager (NSTextViewSupport)

- (NSTextView *) firstTextView {
    for (NSTextContainer *container in [self textContainers]) {
        NSTextView *textView = [container textView];
        if (textView) {
            return textView;
        }
    }
    return nil;
}

- (NSTextView *) textViewForBeginningOfSelection {
    return [self firstTextView];
}

- (BOOL) layoutManagerOwnsFirstResponderInWindow: (NSWindow *) window {
    NSResponder *first = [window firstResponder];

    for (NSTextContainer *container in [self textContainers])
        if ([container textView] == first)
            return YES;

    return NO;
}

- (NSArray *) rulerMarkersForTextView: (NSTextView *) view
                       paragraphStyle: (NSParagraphStyle *) style
                                ruler: (NSRulerView *) ruler
{
    NSMutableArray *markers = [NSMutableArray array];

    CGFloat delta =
            view.textContainer.lineFragmentPadding + view.textContainerOrigin.x;

    // Add the tab stops markers
    for (NSTextTab *textTab in style.tabStops) {
        NSRulerMarker *marker = nil;
        switch (textTab.tabStopType) {
        case NSLeftTabStopType:
            marker = [NSRulerMarker
                    leftTabMarkerWithRulerView: ruler
                                      location: textTab.location + delta];
            break;
        case NSRightTabStopType:
            marker = [NSRulerMarker
                    rightTabMarkerWithRulerView: ruler
                                       location: textTab.location + delta];
            break;
        case NSCenterTabStopType:
            marker = [NSRulerMarker
                    centerTabMarkerWithRulerView: ruler
                                        location: textTab.location + delta];
            break;
        case NSDecimalTabStopType:
            marker = [NSRulerMarker
                    decimalTabMarkerWithRulerView: ruler
                                         location: textTab.location + delta];
            break;
        default:
            break;
        }
        if (marker) {
            [marker setRepresentedObject: textTab];
            [marker setRemovable: YES];
            [markers addObject: marker];
        }
    }
    return markers;
}

- (NSView *) rulerAccessoryViewForTextView: (NSTextView *) view
                            paragraphStyle: (NSParagraphStyle *) style
                                     ruler: (NSRulerView *) ruler
                                   enabled: (BOOL) isEnabled
{
    return nil;
}

@end
