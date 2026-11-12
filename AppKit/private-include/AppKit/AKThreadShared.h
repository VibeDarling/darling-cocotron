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

// Per-thread singletons and per-thread graphics state of AppKit. Darling's Foundation still
// provides similar private calls, but Apple's Foundation does not, so AppKit keeps its own.
// Everything lives in one dictionary under one key of the thread dictionary, so a class name
// coming from a nib can never collide with another user of the thread dictionary. Only the
// current thread is ever touched, so no lock is needed.

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>

static inline NSMutableDictionary *AKThreadSharedDictionary(void) {
    NSMutableDictionary *threadDictionary =
            [[NSThread currentThread] threadDictionary];
    NSMutableDictionary *shared =
            [threadDictionary objectForKey: @"AKThreadSharedObjects"];

    if (shared == nil) {
        shared = [NSMutableDictionary dictionary];
        [threadDictionary setObject: shared forKey: @"AKThreadSharedObjects"];
    }

    return shared;
}

static inline id AKThreadSharedInstanceIfExists(NSString *className) {
    return [AKThreadSharedDictionary() objectForKey: className];
}

// The instance for className on this thread, created with +new on first use.
static inline id AKThreadSharedInstance(NSString *className) {
    id result = AKThreadSharedInstanceIfExists(className);

    if (result == nil) {
        Class cls = NSClassFromString(className);

        if (cls == Nil)
            [NSException raise: NSInternalInconsistencyException
                        format: @"no class named %@ to create a thread-shared instance", className];

        result = [cls new];
        [AKThreadSharedDictionary() setObject: result forKey: className];
        [result release];
    }

    return result;
}

// Replaces the instance for className on this thread; nil removes it.
static inline void AKThreadSetSharedObject(id object, NSString *className) {
    if (object == nil)
        [AKThreadSharedDictionary() removeObjectForKey: className];
    else
        [AKThreadSharedDictionary() setObject: object forKey: className];
}
