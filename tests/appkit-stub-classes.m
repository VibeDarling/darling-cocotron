// Stub classes that applications bind by name: the class exists with the
// guessed superclass, an instance can be made, an unimplemented instance
// message is logged once per class and ignored, and an unimplemented class
// message still raises.
#import <AppKit/AppKit.h>
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

static int stderrSaved = -1;

static void captureStart(const char *path)
{
    stderrSaved = dup(2);
    int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0600);
    dup2(fd, 2);
    close(fd);
}

static NSUInteger captureStop(const char *path)
{
    dup2(stderrSaved, 2);
    close(stderrSaved);
    NSString *text = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:path]
                                               encoding:NSUTF8StringEncoding
                                                  error:NULL];
    return [[text componentsSeparatedByString:@"Stub called"] count] - 1;
}

static void checkStub(NSString *name, Class superclass)
{
    Class cls = NSClassFromString(name);
    expect(cls != Nil, [name stringByAppendingString:@" exists"]);
    expect([cls isSubclassOfClass:superclass],
           [name stringByAppendingString:@" has the guessed superclass"]);
    id object = [[cls alloc] init];
    expect(object != nil, [name stringByAppendingString:@" can be created"]);

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"appkit-stub-classes.log"];
    captureStart([path fileSystemRepresentation]);
    [object performSelector:NSSelectorFromString(@"darlingUnimplementedOne")];
    [object performSelector:NSSelectorFromString(@"darlingUnimplementedTwo")];
    NSUInteger lines = captureStop([path fileSystemRepresentation]);
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    expect(lines == 1, [name stringByAppendingFormat:@" logs once per class, got %lu", (unsigned long)lines]);

    BOOL raised = NO;
    @try
    {
        [cls performSelector:NSSelectorFromString(@"darlingUnimplementedClassMessage")];
    }
    @catch (NSException *exception)
    {
        raised = YES;
    }
    expect(raised, [name stringByAppendingString:@" class messages still raise"]);
    [object release];
}

int main(void)
{
    @autoreleasepool
    {
        checkStub(@"NSSeparatorToolbarItem", [NSToolbarItem class]);
        NSLog(@"PASS: stub classes");
    }
    return 0;
}
