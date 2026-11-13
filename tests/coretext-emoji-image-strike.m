// CTEmojiImageStrike: the class exists in CoreText, can be created, logs one
// "Stub called" line for two unimplemented instance messages and ignores them.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        Class cls = NSClassFromString(@"CTEmojiImageStrike");
        expect(cls != Nil, @"CTEmojiImageStrike exists");
        expect([cls isSubclassOfClass:[NSObject class]], @"it is an NSObject subclass");
        id object = [[cls alloc] init];
        expect(object != nil, @"an instance can be created");

        const char *path = [[NSTemporaryDirectory()
            stringByAppendingPathComponent:@"coretext-emoji-image-strike.log"] fileSystemRepresentation];
        int saved = dup(2);
        int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0600);
        dup2(fd, 2);
        close(fd);
        [object performSelector:NSSelectorFromString(@"darlingUnimplementedOne")];
        [object performSelector:NSSelectorFromString(@"darlingUnimplementedTwo")];
        dup2(saved, 2);
        close(saved);

        NSString *text = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:path]
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL];
        unlink(path);
        NSUInteger lines = [[text componentsSeparatedByString:@"Stub called"] count] - 1;
        expect(lines == 1, [NSString stringWithFormat:@"one log line, got %lu", (unsigned long)lines]);
        [object release];
        NSLog(@"PASS: CTEmojiImageStrike");
    }
    return 0;
}
