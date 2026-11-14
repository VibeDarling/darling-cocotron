// NSApplicationMain takes the documents to open from the process arguments, not from the argc/argv it is
// handed. Chess hands over an argv advanced to its last argument together with the original argc, so argv[1]
// is NULL; reading it crashed the app on launch whenever it was started with any argument.
// The test re-runs itself with arguments, hands NSApplicationMain that same kind of argv and checks the
// NSOpen default it leaves behind, then clears NSOpen and checks the fallback in -openFiles the same way: the
// value of -NSBindingDebugLogLevel ("2") is not a document. Needs a display, like the other AppKit tests.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
        exit(1);
    }
}

static NSMutableArray *openedFiles;

@interface Recorder : NSObject
@end

@implementation Recorder
- (BOOL) application: (NSApplication *) sender openFile: (NSString *) filename
{
    [openedFiles addObject: filename];
    return YES;
}
- (void) application: (NSApplication *) sender openFiles: (NSArray *) filenames
{
    [openedFiles addObjectsFromArray: filenames];
}
@end

static BOOL loadNibStub(id self, SEL _cmd, NSString *name, id owner)
{
    return YES;
}

// Stands in for -[NSApplication run]: NSApplicationMain has parsed the arguments by the time it calls it.
static void runStub(id self, SEL _cmd)
{
    id nsOpen = [[NSUserDefaults standardUserDefaults] objectForKey: @"NSOpen"];
    expect([nsOpen isEqual: @"/tmp/segv-tc-document.txt"],
           [NSString stringWithFormat: @"NSOpen is %@, expected the one document argument", nsOpen]);

    openedFiles = [NSMutableArray array];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"NSOpen"];
    [NSApp setDelegate: [[Recorder alloc] init]];
    [NSApp performSelector: NSSelectorFromString(@"openFiles")];
    expect([openedFiles isEqual: @[@"/tmp/segv-tc-document.txt"]],
           [NSString stringWithFormat: @"-openFiles opened %@, expected the one document argument", openedFiles]);
    printf("PASS\n");
    exit(0);
}

int main(int argc, char **argv)
{
    if (argc == 1)
    {
        char *childArgv[] = {argv[0], "-NSBindingDebugLogLevel", "2", "/tmp/segv-tc-document.txt", NULL};
        pid_t pid;
        expect(posix_spawn(&pid, argv[0], NULL, NULL, childArgv, environ) == 0, @"could not start the child");
        int status = 0;
        expect(waitpid(pid, &status, 0) == pid, @"waitpid failed");
        expect(!WIFSIGNALED(status), [NSString stringWithFormat: @"the child died on signal %d", WTERMSIG(status)]);
        return WEXITSTATUS(status);
    }

    class_replaceMethod(object_getClass([NSBundle class]), @selector(loadNibNamed:owner:), (IMP)loadNibStub, "B@:@@");
    class_replaceMethod([NSApplication class], @selector(run), (IMP)runStub, "v@:");
    return NSApplicationMain(argc, (const char **)(argv + argc - 1));
}
