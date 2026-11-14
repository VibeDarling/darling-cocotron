#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

// NSFilePromiseReceiver (NSFilePromiseReceiver.h, macOS 10.12) is what Shortcuts, TV and Notes bind to accept
// promised files. Nothing here can keep a file promise, so receiving reports the failure through the reader, as the
// header says a failed or cancelled write does.
static void expect(BOOL condition, NSString *message) {
    if (!condition) {
        printf("FAIL: %s\n", [message UTF8String]);
        exit(1);
    }
}

static Class receiverClass;

static NSFilePromiseReceiver *receiverFor(id propertyList) {
    return [[[receiverClass alloc]
            initWithPasteboardPropertyList: propertyList
                                    ofType: @"com.apple.pasteboard.promised-file-content-type"] autorelease];
}

int main(void) {
    @autoreleasepool {
        // Looked up by name so the test runs, and fails with a message, against an AppKit that lacks the class.
        Class cls = receiverClass = objc_getClass("NSFilePromiseReceiver");
        expect(cls != Nil, @"NSFilePromiseReceiver is registered");
        expect(class_conformsToProtocol(cls, @protocol(NSPasteboardReading)), @"it reads from the pasteboard");

        NSArray *types = [cls readableDraggedTypes];
        expect([types count] > 0, @"there are readable drag types");
        for (id type in types)
            expect([type isKindOfClass: [NSString class]] && [type length] > 0, @"every readable type is a string");
        expect([types containsObject: @"com.apple.pasteboard.promised-file-content-type"], @"the promised content type is readable");
        expect([types containsObject: NSFilesPromisePboardType], @"the legacy promise type is readable");
        expect([[cls readableTypesForPasteboard: nil] isEqual: types], @"the pasteboard reads the same types");

        NSFilePromiseReceiver *single = receiverFor(@"public.png");
        expect([[single fileTypes] isEqual: @[@"public.png"]], @"a UTI string promises one file type");
        expect([[single fileNames] count] == 0, @"no file names before the promise is called in");

        NSFilePromiseReceiver *several = receiverFor(@[@"public.png", @"public.jpeg", @42, @""]);
        expect([[several fileTypes] isEqual: (@[@"public.png", @"public.jpeg"])], @"a list keeps its non-empty strings");

        NSFilePromiseReceiver *fromData = receiverFor([@"public.pdf" dataUsingEncoding: NSUTF8StringEncoding]);
        expect([[fromData fileTypes] isEqual: @[@"public.pdf"]], @"UTF-8 data is read as a UTI string");

        expect([[receiverFor(@42) fileTypes] count] == 0, @"an unrelated property list promises nothing");
        expect([[receiverFor(@"") fileTypes] count] == 0, @"an empty string promises nothing");

        NSOperationQueue *queue = [[NSOperationQueue new] autorelease];
        NSURL *destination = [NSURL fileURLWithPath: NSTemporaryDirectory()];
        NSLock *lock = [[NSLock new] autorelease];
        __block int calls = 0, wrongQueue = 0, withURL = 0, withoutError = 0, wrongError = 0;
        [several receivePromisedFilesAtDestination: destination
                                           options: @{}
                                    operationQueue: queue
                                            reader: ^(NSURL *fileURL, NSError *error) {
            [lock lock];
            calls++;
            if ([NSOperationQueue currentQueue] != queue) wrongQueue++;
            if (fileURL != nil) withURL++;
            if (error == nil) withoutError++;
            else if (![[error domain] isEqualToString: NSCocoaErrorDomain] || [error code] != NSFeatureUnsupportedError) wrongError++;
            [lock unlock];
        }];
        [queue waitUntilAllOperationsAreFinished];
        expect(calls == 2, @"the reader is called once per promised file");
        expect(wrongQueue == 0, @"the reader runs on the given queue");
        expect(withURL == 0, @"no file URL is reported for a failed promise");
        expect(withoutError == 0, @"every call carries an error");
        expect(wrongError == 0, @"the error says the feature is unsupported");
        expect([[several fileNames] count] == 0, @"no file names after a failed promise");

        __block int none = 0;
        [receiverFor(nil) receivePromisedFilesAtDestination: destination
                                                    options: @{}
                                             operationQueue: queue
                                                     reader: ^(NSURL *fileURL, NSError *error) { none++; }];
        [queue waitUntilAllOperationsAreFinished];
        expect(none == 0, @"a receiver with no promised file never calls the reader");
    }
    printf("PASS: file promise receiver\n");
    return 0;
}
