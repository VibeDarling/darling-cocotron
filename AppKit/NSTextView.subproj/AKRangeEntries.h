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

#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

// AppKit-private: not exported from AppKit.
#define AK_PRIVATE_EXTERN extern __attribute__((visibility("hidden")))

// an ordered, nonoverlapping set of NSRanges and related value
typedef struct AKRangeEntries AKRangeEntries;

typedef struct {
    AKRangeEntries *self;
    NSUInteger index;
} AKRangeEnumerator;

AK_PRIVATE_EXTERN AKRangeEntries *
AKCreateRangeToOwnedPointerEntries(NSUInteger capacity);
AK_PRIVATE_EXTERN AKRangeEntries *
AKCreateRangeToCopiedObjectEntries(NSUInteger capacity);

AK_PRIVATE_EXTERN void AKFreeRangeEntries(AKRangeEntries *self);
AK_PRIVATE_EXTERN void AKResetRangeEntries(AKRangeEntries *self);
AK_PRIVATE_EXTERN NSUInteger AKCountRangeEntries(AKRangeEntries *self);
AK_PRIVATE_EXTERN void AKRangeEntriesRemoveEntryAtIndex(AKRangeEntries *self,
                                                        NSUInteger index);

AK_PRIVATE_EXTERN void AKRangeEntryInsert(AKRangeEntries *self, NSRange range,
                                          void *value);
AK_PRIVATE_EXTERN void *AKRangeEntryAtIndex(AKRangeEntries *self,
                                            NSUInteger index,
                                            NSRange *effectiveRange);
AK_PRIVATE_EXTERN void *AKRangeEntryAtRange(AKRangeEntries *self,
                                            NSRange range);

AK_PRIVATE_EXTERN AKRangeEnumerator
AKRangeEntryEnumerator(AKRangeEntries *self);
AK_PRIVATE_EXTERN BOOL AKNextRangeEnumeratorEntry(AKRangeEnumerator *state,
                                                  NSRange *rangep,
                                                  void **value);

AK_PRIVATE_EXTERN void AKRangeEntriesExpandAndWipe(AKRangeEntries *self,
                                                   NSRange range,
                                                   NSInteger delta);
AK_PRIVATE_EXTERN void AKRangeEntriesDivideAndConquer(AKRangeEntries *self,
                                                      NSRange range);
AK_PRIVATE_EXTERN void AKRangeEntriesVerify(AKRangeEntries *self,
                                            NSUInteger length);
