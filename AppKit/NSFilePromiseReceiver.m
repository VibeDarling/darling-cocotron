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

#import <AppKit/NSFilePromiseReceiver.h>
#import <Foundation/NSError.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

// HIServices Pasteboard.h: kPasteboardTypeFilePromiseContent holds "a UTF-8 encoded UTI describing the type of
// data to be contained within the promised file"; the receiver reads it to decide whether it wants the file.
static NSString *const FilePromiseContentType =
        @"com.apple.pasteboard.promised-file-content-type";

@implementation NSFilePromiseReceiver

// GUESS: no public source says what the property list of a promise is beyond the content type above, so the types
// a receiver reads are that one and the legacy HFS-style promise type (a list of file types).
+ (NSArray<NSString *> *) readableDraggedTypes {
    return [NSArray arrayWithObjects: FilePromiseContentType,
                                      NSFilesPromisePboardType, nil];
}

+ (NSArray<NSPasteboardType> *) readableTypesForPasteboard:
        (NSPasteboard *) pasteboard {
    return [self readableDraggedTypes];
}

// The promised file types: a UTI string (as the pasteboard holds it, or as UTF-8 data), or a list of them for the
// legacy type. Anything else promises nothing.
+ (NSArray *) fileTypesFromPropertyList: (id) propertyList {
    if ([propertyList isKindOfClass: [NSData class]])
        propertyList = [[[NSString alloc] initWithData: propertyList
                                              encoding: NSUTF8StringEncoding]
                autorelease];

    if ([propertyList isKindOfClass: [NSString class]])
        return [propertyList length] > 0 ? [NSArray arrayWithObject: propertyList]
                                         : [NSArray array];

    NSMutableArray *types = [NSMutableArray array];
    if ([propertyList isKindOfClass: [NSArray class]]) {
        for (id type in propertyList)
            if ([type isKindOfClass: [NSString class]] && [type length] > 0)
                [types addObject: type];
    }
    return types;
}

- (instancetype) initWithPasteboardPropertyList: (id) propertyList
                                         ofType: (NSPasteboardType) type {
    self = [super init];
    if (self) {
        _fileTypes = [[[self class] fileTypesFromPropertyList: propertyList] copy];
        _fileNames = [[NSArray alloc] init];
    }
    return self;
}

- (instancetype) init {
    return [self initWithPasteboardPropertyList: nil ofType: nil];
}

- (void) dealloc {
    [_fileTypes release];
    [_fileNames release];
    [super dealloc];
}

- (NSArray<NSString *> *) fileTypes {
    return _fileTypes;
}

- (NSArray<NSString *> *) fileNames {
    return _fileNames;
}

// Calling a promise in needs the sender, which keeps it in the dragging source's process through the pasteboard's
// promise machinery; NSPasteboard here has none (readObjectsForClasses: is a stub), so no promise can be kept.
// The header says the reader is still called, with an error, when writing a promised file fails: it is called
// once per promised file with no URL, on the given queue (the current queue if none is given).
- (void) receivePromisedFilesAtDestination: (NSURL *) destinationDir
                                   options: (NSDictionary *) options
                            operationQueue: (NSOperationQueue *) operationQueue
                                    reader: (void (^)(NSURL *fileURL,
                                                    NSError *errorOrNil))reader {
    NSError *error = [NSError
            errorWithDomain: NSCocoaErrorDomain
                       code: NSFeatureUnsupportedError
                   userInfo: [NSDictionary
                                     dictionaryWithObject:
                                             @"Darling has no file promise delivery: nothing writes the promised file"
                                                   forKey: NSLocalizedDescriptionKey]];
    void (^copiedReader)(NSURL *, NSError *) = [reader copy];

    for (NSUInteger i = 0; i < [_fileTypes count]; i++) {
        void (^deliver)(void) = ^{
            copiedReader(nil, error);
        };
        if (operationQueue != nil)
            [operationQueue addOperationWithBlock: deliver];
        else
            deliver();
    }
    [copiedReader release];
}

@end
