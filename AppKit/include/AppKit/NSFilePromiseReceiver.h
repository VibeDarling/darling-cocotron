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

#import <AppKit/NSPasteboard.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>

@class NSOperationQueue, NSURL, NSError;

@interface NSFilePromiseReceiver : NSObject <NSPasteboardReading> {
    NSArray *_fileTypes;
    NSArray *_fileNames;
}

+ (NSArray<NSString *> *) readableDraggedTypes;

@property(copy, readonly) NSArray<NSString *> *fileTypes;
@property(copy, readonly) NSArray<NSString *> *fileNames;

- (void) receivePromisedFilesAtDestination: (NSURL *) destinationDir
                                   options: (NSDictionary *) options
                            operationQueue: (NSOperationQueue *) operationQueue
                                    reader: (void (^)(NSURL *fileURL,
                                                    NSError *errorOrNil))reader;

// NSPasteboardReading
+ (NSArray<NSPasteboardType> *) readableTypesForPasteboard:
        (NSPasteboard *) pasteboard;
- (instancetype) initWithPasteboardPropertyList: (id) propertyList
                                         ofType: (NSPasteboardType) type;

@end
