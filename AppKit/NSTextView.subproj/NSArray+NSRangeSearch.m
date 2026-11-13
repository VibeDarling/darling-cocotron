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

// The private -[NSArray indexOfFirstRangeContainingOrFollowing:] that the cache's text code sends to an array of
// NSValue ranges (a text view's selectedRanges). No public declaration exists; the receiver (an array of range
// values) and the argument (one character index, observed as 0 for a lone insertion point) come from a Darling-side
// log of the call.
//
// GUESS (rung 6, from the name; NEEDS-REAL-MAC for the edge cases). Precondition: the receiver is sorted and its
// ranges do not overlap, as NSTextView's public documentation describes selected ranges; Cocotron's
// setSelectedRanges: stores the array as given, so an unsorted array gets the first match in array order, not the
// lowest range. For a sorted array the answer is the index of the first range that contains the character index or
// lies at or after it, NSNotFound when every range ends before it. An empty range at the character index (an
// insertion point) counts as containing it. NSMaxRange wraps for a range {location, NSUIntegerMax}; that cannot
// happen for a text selection.

#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSRange.h>

@interface NSArray (NSRangeSearch)
- (NSUInteger) indexOfFirstRangeContainingOrFollowing: (NSUInteger) characterIndex;
@end

@implementation NSArray (NSRangeSearch)

- (NSUInteger) indexOfFirstRangeContainingOrFollowing: (NSUInteger) characterIndex {
    NSUInteger count = [self count];

    for (NSUInteger i = 0; i < count; i++) {
        NSRange range = [[self objectAtIndex: i] rangeValue];

        if (range.location >= characterIndex || NSMaxRange(range) > characterIndex)
            return i;
    }
    return NSNotFound;
}

@end
