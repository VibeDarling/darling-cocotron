#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <stdlib.h>

// -[NSText writeRTFDToFile:atomically:] hands the RTFD file wrapper to the wrapper's own write,
// -[NSFileWrapper writeToURL:options:originalContentsURL:error:] (atomic when asked), or where a Foundation lacks
// it (Darling's own) the deprecated writeToFile:atomically:updateFilenames:, onto a destination that has not been
// created first: on Apple's Foundation the deprecated call on a directory made beforehand returns NO and writes nothing.
static NSMutableArray *calls;
static NSMutableDictionary<NSString *, NSValue *> *originals;

static void expect(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSValue *originalFor(id self, SEL _cmd)
{
    for (Class c = object_getClass(self); c != Nil; c = class_getSuperclass(c)) {
        NSValue *original = originals[[NSStringFromClass(c) stringByAppendingFormat:@" %@", NSStringFromSelector(_cmd)]];
        if (original)
            return original;
    }
    return nil;
}

static BOOL spyWriteFile(id self, SEL _cmd, NSString *path, BOOL atomically, BOOL updateFilenames)
{
    BOOL existed = [[NSFileManager defaultManager] fileExistsAtPath:path];
    [calls addObject:[NSString stringWithFormat:@"writeToFile:atomically:%d existed:%d", atomically, existed]];
    return ((BOOL (*)(id, SEL, NSString *, BOOL, BOOL)) [originalFor(self, _cmd) pointerValue])(self, _cmd, path, atomically, updateFilenames);
}

static BOOL spyWriteURL(id self, SEL _cmd, NSURL *url, NSUInteger options, NSURL *original, NSError **error)
{
    BOOL existed = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    [calls addObject:[NSString stringWithFormat:@"writeToURL:options:%lu existed:%d", (unsigned long) options, existed]];
    return ((BOOL (*)(id, SEL, NSURL *, NSUInteger, NSURL *, NSError **)) [originalFor(self, _cmd) pointerValue])(self, _cmd, url, options, original, error);
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        BOOL hasURLWrite = [[[[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{}] autorelease] respondsToSelector:@selector(writeToURL:options:originalContentsURL:error:)];
        NSLog(@"wrapper has writeToURL:options:originalContentsURL:error: %d", hasURLWrite);
        calls = [[NSMutableArray alloc] init];
        originals = [[NSMutableDictionary alloc] init];
        SEL writeFile = @selector(writeToFile:atomically:updateFilenames:);
        SEL writeURL = @selector(writeToURL:options:originalContentsURL:error:);
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            BOOL inFamily = NO;
            for (Class c = classes[i]; c != Nil; c = class_getSuperclass(c))
                if (c == [NSFileWrapper class])
                    inFamily = YES;
            if (!inFamily)
                continue;
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(classes[i], &methodCount);
            for (unsigned int m = 0; m < methodCount; m++) {
                SEL name = method_getName(methods[m]);
                if (name != writeFile && name != writeURL)
                    continue;
                originals[[NSStringFromClass(classes[i]) stringByAppendingFormat:@" %@", NSStringFromSelector(name)]] =
                        [NSValue valueWithPointer:method_getImplementation(methods[m])];
                method_setImplementation(methods[m], name == writeFile ? (IMP) spyWriteFile : (IMP) spyWriteURL);
            }
            free(methods);
        }
        free(classes);

        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
        expect([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL], @"scratch directory");
        NSString *rtfd = [directory stringByAppendingPathComponent:@"note.rtfd"];
        NSTextView *text = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)] autorelease];

        [text setString:@"first line"];
        expect([text writeRTFDToFile:rtfd atomically:YES], @"atomic write to a new destination succeeded");
        expect([calls count] >= 1 && [calls[0] isEqualToString:hasURLWrite ? @"writeToURL:options:1 existed:0" : @"writeToFile:atomically:1 existed:0"],
               [NSString stringWithFormat:@"the wrapper wrote itself atomically onto a destination not created first, calls: %@", calls]);
        NSData *rtf = [NSData dataWithContentsOfFile:[rtfd stringByAppendingPathComponent:@"TXT.rtf"]];
        expect([[[[NSString alloc] initWithData:rtf encoding:NSUTF8StringEncoding] autorelease] containsString:@"first line"], @"TXT.rtf holds the text");

        [calls removeAllObjects];
        [text setString:@"second line"];
        expect([text writeRTFDToFile:rtfd atomically:YES], @"atomic write over the existing RTFD succeeded");
        expect([calls count] >= 1 && [calls[0] isEqualToString:hasURLWrite ? @"writeToURL:options:1 existed:1" : @"writeToFile:atomically:1 existed:1"], [NSString stringWithFormat:@"calls over an existing RTFD: %@", calls]);
        rtf = [NSData dataWithContentsOfFile:[rtfd stringByAppendingPathComponent:@"TXT.rtf"]];
        NSString *content = [[[NSString alloc] initWithData:rtf encoding:NSUTF8StringEncoding] autorelease];
        expect([content containsString:@"second line"] && ![content containsString:@"first line"], @"TXT.rtf holds only the replacement");

        [calls removeAllObjects];
        // a non-atomic request over an existing RTFD is still written atomically, so the old item survives a failure
        [text setString:@"third line"];
        expect([text writeRTFDToFile:rtfd atomically:NO], @"non-atomic request over an existing RTFD succeeded");
        expect([calls count] >= 1 && [calls[0] isEqualToString:hasURLWrite ? @"writeToURL:options:1 existed:1" : @"writeToFile:atomically:0 existed:1"], [NSString stringWithFormat:@"non-atomic request over an existing RTFD: %@", calls]);

        [calls removeAllObjects];
        NSString *plain = [directory stringByAppendingPathComponent:@"plain.rtfd"];
        expect([text writeRTFDToFile:plain atomically:NO], @"non-atomic write to a new destination succeeded");
        expect([calls count] >= 1 && [calls[0] isEqualToString:hasURLWrite ? @"writeToURL:options:1 existed:0" : @"writeToFile:atomically:0 existed:0"], [NSString stringWithFormat:@"non-atomic call: %@", calls]);

        // the folders above the destination are created, as before
        NSString *nested = [directory stringByAppendingPathComponent:@"a/b/nested.rtfd"];
        expect([text writeRTFDToFile:nested atomically:YES], @"a destination below folders that do not exist yet is written");
        expect([[NSFileManager defaultManager] fileExistsAtPath:[nested stringByAppendingPathComponent:@"TXT.rtf"]], @"and is there");

        [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
        NSLog(@"PASS: the RTFD wrapper writes itself, atomically when asked, onto a destination not created first");
    }
    return 0;
}
