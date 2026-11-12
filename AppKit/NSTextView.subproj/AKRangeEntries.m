/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

/* Private AppKit copy of Foundation's NSRangeEntries, prefixed AK so that
   AppKit does not import it from Foundation. */

#import "AKRangeEntries.h"
#import <Foundation/NSString.h>

/* this could be improved with more merging of adjacent entries after
 * insert/remove */

typedef struct AKRangeEntry {
    NSRange range;
    void *value;
} AKRangeEntry;

struct AKRangeEntries {
    NSUInteger capacity;
    NSUInteger count;
    struct AKRangeEntry *entries;
    BOOL objects;
};

AKRangeEntries *AKCreateRangeToOwnedPointerEntries(NSUInteger capacity) {
    AKRangeEntries *result = NSZoneMalloc(NULL, sizeof(AKRangeEntries));

    result->capacity = (capacity < 4) ? 4 : capacity;
    result->count = 0;
    result->entries =
            NSZoneMalloc(NULL, sizeof(AKRangeEntry) * result->capacity);
    result->objects = NO;

    return result;
}

AKRangeEntries *AKCreateRangeToCopiedObjectEntries(NSUInteger capacity) {
    AKRangeEntries *result = AKCreateRangeToOwnedPointerEntries(capacity);

    result->objects = YES;

    return result;
}

void AKFreeRangeEntries(AKRangeEntries *self) {
    if (self == NULL) {
        return;
    }
    AKResetRangeEntries(self);
    NSZoneFree(NULL, self->entries);
    NSZoneFree(NULL, self);
}

void AKResetRangeEntries(AKRangeEntries *self) {
    if (self == NULL) {
        return;
    }
    NSInteger i;

    for (i = 0; i < self->count; i++)
        if (self->objects)
            [(id) self->entries[i].value release];
        else
            NSZoneFree(NULL, self->entries[i].value);

    self->count = 0;
}

NSUInteger AKCountRangeEntries(AKRangeEntries *self) {
    if (self == NULL) {
        return 0;
    }
    return self->count;
}

static inline void removeEntryAtIndex(AKRangeEntries *self, NSUInteger index) {
    if (self->objects)
        [(id) self->entries[index].value release];
    else
        NSZoneFree(NULL, self->entries[index].value);

    self->count--;
    for (; index < self->count; index++)
        self->entries[index] = self->entries[index + 1];
}

static inline void insertEntryAtIndex(AKRangeEntries *self, NSUInteger index,
                                      NSRange range, void *value)
{
    NSInteger i;

    self->count++;
    if (self->count > self->capacity) {
        self->capacity *= 2;
        self->entries = NSZoneRealloc(NULL, self->entries,
                                      sizeof(AKRangeEntry) * self->capacity);
    }

    for (i = self->count; --i > index;)
        self->entries[i] = self->entries[i - 1];

    if (self->objects)
        value = [(id) value copy];

    self->entries[index].range = range;
    self->entries[index].value = value;
}

void AKRangeEntryInsert(AKRangeEntries *self, NSRange range, void *value) {
    NSInteger count = self->count;
    NSInteger bottom = 0, top = count;
    NSInteger insertAt = 0;

    if (count > 0) {
        while (top >= bottom) {
            NSInteger mid = (bottom + top) / 2;
            NSRange check = self->entries[mid].range;

            if (range.location >= NSMaxRange(check)) {
                NSInteger next = mid + 1;

                if (next >= count ||
                    NSMaxRange(range) <= self->entries[next].range.location) {
                    insertAt = next;
                    break;
                }
                bottom = mid + 1;
            } else {
                NSInteger prev = mid - 1;

                if (prev < 0 ||
                    range.location >= NSMaxRange(self->entries[prev].range)) {
                    insertAt = mid;
                    break;
                }
                top = mid - 1;
            }
        }
    }
    BOOL merged = NO;
    if (range.length == 0) {
        // We'll just try to merge entries around the location
        if (self->objects && insertAt > 0 && insertAt < self->count) {
            id prev = self->entries[insertAt - 1].value;
            id next = self->entries[insertAt].value;
            if ([prev isEqual: next]) {
                range = NSUnionRange(self->entries[insertAt].range,
                                     self->entries[insertAt - 1].range);
                self->entries[insertAt - 1].range = range;
                removeEntryAtIndex(self, insertAt);
            }
        }
        // We don't really want to insert a 0 length entry
        return;
    } else {
        if (self->objects) {
            if (insertAt > 0) {
                // Check if we can just merge the new entry with the previous
                // one
                if (range.length == 0 ||
                    [(id)(self->entries[insertAt - 1].value) isEqual: value]) {
                    range = NSUnionRange(self->entries[insertAt - 1].range,
                                         range);
                    self->entries[insertAt - 1].range = range;
                    merged = YES;
                }
            }
            if (insertAt < self->count) {
                // Check if we can just merge the new entry with the next one
                if (range.length == 0 ||
                    [(id)(self->entries[insertAt].value) isEqual: value]) {
                    range = NSUnionRange(self->entries[insertAt].range, range);
                    if (merged) {
                        // We merged with both the previous entry and the next
                        // one - the next one isn't needed anymore so just merge
                        // it with the previous one
                        self->entries[insertAt - 1].range = range;
                        removeEntryAtIndex(self, insertAt);
                    } else {
                        self->entries[insertAt].range = range;
                    }
                    merged = YES;
                    ;
                }
            }
        }
    }
    if (merged == NO) {
        insertEntryAtIndex(self, insertAt, range, value);
    }
}

void *AKRangeEntryAtIndex(AKRangeEntries *self, NSUInteger location,
                          NSRange *effectiveRangep)
{
    if (self == NULL) {
        if (effectiveRangep != NULL)
            *effectiveRangep = NSMakeRange(NSNotFound, 0);
        return NULL;
    }
    NSInteger count = self->count;
    NSInteger bottom = 0, top = count;

    if (top == 0) {
        if (effectiveRangep != NULL)
            *effectiveRangep = NSMakeRange(NSNotFound, 0);
        return NULL;
    }

    while (top >= bottom) {
        NSInteger mid = (bottom + top) / 2;
        NSRange check = self->entries[mid].range;

        if (NSLocationInRange(location, check)) {
            if (effectiveRangep != NULL)
                *effectiveRangep = check;
            return self->entries[mid].value;
        } else if (location >= NSMaxRange(check)) {
            NSInteger next = mid + 1;

            if (next >= count) {
                if (effectiveRangep != NULL) {
                    effectiveRangep->location = NSMaxRange(check);
                    effectiveRangep->length = NSNotFound;
                }
                return NULL;
            } else if (location < self->entries[next].range.location) {
                if (effectiveRangep != NULL) {
                    effectiveRangep->location = NSMaxRange(check);
                    effectiveRangep->length =
                            self->entries[next].range.location -
                            NSMaxRange(check);
                }
                return NULL;
            }
            bottom = mid + 1;
        } else {
            NSInteger prev = mid - 1;

            if (prev < 0) {
                if (effectiveRangep != NULL) {
                    effectiveRangep->location = 0;
                    effectiveRangep->length = check.location;
                }
                return NULL;
            } else if (location >= NSMaxRange(self->entries[prev].range)) {
                if (effectiveRangep != NULL) {
                    effectiveRangep->location =
                            NSMaxRange(self->entries[prev].range);
                    effectiveRangep->length =
                            check.location - effectiveRangep->location;
                }
                return NULL;
            }
            top = mid - 1;
        }
    }

    NSLog(@"not supposed to get here %d", __LINE__);
    return NULL;
}

void *AKRangeEntryAtRange(AKRangeEntries *self, NSRange range) {
    if (self == NULL) {
        return NULL;
    }
    NSInteger bottom = 0, top = self->count;

    if (top > 0) {
        while (top >= bottom) {
            NSInteger mid = (bottom + top) / 2;
            NSRange check = self->entries[mid].range;

            if (NSEqualRanges(range, check))
                return self->entries[mid].value;
            else if (range.location >= NSMaxRange(check))
                bottom = mid + 1;
            else
                top = mid - 1;
        }
    }

    return NULL;
}

AKRangeEnumerator AKRangeEntryEnumerator(AKRangeEntries *self) {
    AKRangeEnumerator result;

    result.self = self;
    result.index = 0;

    return result;
}

BOOL AKNextRangeEnumeratorEntry(AKRangeEnumerator *state, NSRange *rangep,
                                void **valuep)
{
    AKRangeEntries *self = state->self;

    if (self == NULL || state->index >= self->count)
        return NO;

    *rangep = self->entries[state->index].range;
    *valuep = self->entries[state->index].value;
    state->index++;

    return YES;
}

void AKRangeEntriesRemoveEntryAtIndex(AKRangeEntries *self, NSUInteger index) {
    removeEntryAtIndex(self, index);
}
