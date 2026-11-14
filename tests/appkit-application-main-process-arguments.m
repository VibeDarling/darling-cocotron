// NSApplicationMain takes the documents to open from the process arguments, not from the argc/argv it is
// handed. Chess hands over an argv advanced to its last argument together with the original argc, so argv[1]
// is NULL; reading it crashed the app on launch whenever it was started with any argument.
// The test re-runs itself once per argument list below, hands NSApplicationMain that same kind of argv and checks
// the NSOpen default it leaves behind, then hides NSOpen and checks the fallback in -openFiles the same way:
// the value of -NSBindingDebugLogLevel ("2") is not a document, -NSOpen takes no value, empty arguments name
// nothing and every argument after "--" is a document. NSUserDefaults is wrapped so that both checks see what
// the code stores and reads, whatever the argument domain says. Needs a display, like the other AppKit tests.
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
static id storedNSOpen;
static BOOL hideNSOpen;
static IMP originalSetObject, originalObjectForKey;

static BOOL isNSOpen(id key)
{
    return [key isEqual: @"NSOpen"];
}

static void setObjectStub(id self, SEL _cmd, id object, NSString *key)
{
    if (isNSOpen(key))
        storedNSOpen = [object retain];
    ((void (*)(id, SEL, id, id))originalSetObject)(self, _cmd, object, key);
}

static id objectForKeyStub(id self, SEL _cmd, NSString *key)
{
    if (isNSOpen(key) && hideNSOpen)
        return nil;
    return ((id (*)(id, SEL, id))originalObjectForKey)(self, _cmd, key);
}

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

#define MAX_ARGS 12

static const struct
{
    const char *arguments[MAX_ARGS];
    const char *documents[MAX_ARGS];
} cases[] = {
    // a switch takes the next argument as its value
    {{"-NSBindingDebugLogLevel", "2", "/tmp/appmain-document.txt"}, {"/tmp/appmain-document.txt"}},
    // -NSOpen takes no value, "" names nothing, everything after "--" is a document, switches included
    {{"-NSOpen", "a", "", "b", "--", "-d", "c", "", "--"}, {"a", "b", "-d", "c", "--"}},
};
#define CASE_COUNT (sizeof(cases) / sizeof(cases[0]))

static NSArray *expectedDocuments(size_t index)
{
    NSMutableArray *documents = [NSMutableArray array];
    for (int i = 0; i < MAX_ARGS && cases[index].documents[i] != NULL; i++)
        [documents addObject: [NSString stringWithUTF8String: cases[index].documents[i]]];
    return documents;
}

static BOOL loadNibStub(id self, SEL _cmd, NSString *name, id owner)
{
    return YES;
}

// Stands in for -[NSApplication run]: NSApplicationMain has parsed the arguments by the time it calls it.
static void runStub(id self, SEL _cmd)
{
    NSArray *expected = expectedDocuments(atoi(getenv("APPMAIN_CASE")));
    NSArray *stored = [storedNSOpen isKindOfClass: [NSString class]] ? @[storedNSOpen] : storedNSOpen;
    expect([stored isEqual: expected],
           [NSString stringWithFormat: @"NSOpen is %@, expected %@", storedNSOpen, expected]);
    expect([storedNSOpen isKindOfClass: [NSString class]] == ([expected count] == 1),
           [NSString stringWithFormat: @"NSOpen is %@, a single document is stored as a string", storedNSOpen]);

    openedFiles = [NSMutableArray array];
    hideNSOpen = YES;
    [NSApp setDelegate: [[Recorder alloc] init]];
    [NSApp performSelector: NSSelectorFromString(@"openFiles")];
    expect([openedFiles isEqual: expected],
           [NSString stringWithFormat: @"-openFiles opened %@, expected %@", openedFiles, expected]);
    printf("PASS\n");
    exit(0);
}

int main(int argc, char **argv)
{
    if (argc == 1)
    {
        int failures = 0;
        for (size_t c = 0; c < CASE_COUNT; c++)
        {
            char *childArgv[MAX_ARGS + 2] = {argv[0]};
            for (int i = 0; i < MAX_ARGS && cases[c].arguments[i] != NULL; i++)
                childArgv[i + 1] = (char *)cases[c].arguments[i];
            char caseNumber[8];
            snprintf(caseNumber, sizeof(caseNumber), "%zu", c);
            setenv("APPMAIN_CASE", caseNumber, 1);
            pid_t pid;
            expect(posix_spawn(&pid, argv[0], NULL, NULL, childArgv, environ) == 0, @"could not start the child");
            int status = 0;
            expect(waitpid(pid, &status, 0) == pid, @"waitpid failed");
            if (WIFSIGNALED(status))
                fprintf(stderr, "FAIL: case %zu: the child died on signal %d\n", c, WTERMSIG(status));
            else if (WEXITSTATUS(status) != 0)
                fprintf(stderr, "FAIL: case %zu: the child exited with %d\n", c, WEXITSTATUS(status));
            else
                continue;
            failures++;
        }
        if (failures == 0)
            printf("PASS\n");
        return failures != 0;
    }

    originalSetObject = class_replaceMethod([NSUserDefaults class], @selector(setObject:forKey:), (IMP)setObjectStub, "v@:@@");
    originalObjectForKey = class_replaceMethod([NSUserDefaults class], @selector(objectForKey:), (IMP)objectForKeyStub, "@@:@");
    class_replaceMethod(object_getClass([NSBundle class]), @selector(loadNibNamed:owner:), (IMP)loadNibStub, "B@:@@");
    class_replaceMethod([NSApplication class], @selector(run), (IMP)runStub, "v@:");
    return NSApplicationMain(argc, (const char **)(argv + argc - 1));
}
