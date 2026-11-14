#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Private AppKit functions that stock applications import (Calendar, Notes, Contacts). They are exported so the
// applications bind; nothing public documents their results, so a call aborts instead of inventing one.
static int abortsWhenCalled(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) {
        printf("FAIL: %s is not exported\n", name);
        return 0;
    }
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function();
        _exit(0);
    }
    int status = 0;
    if (waitpid(child, &status, 0) != child || !WIFSIGNALED(status) || WTERMSIG(status) != SIGABRT) {
        printf("FAIL: calling %s does not abort\n", name);
        return 0;
    }
    return 1;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int ok = abortsWhenCalled("NSSidebarMetricsForRowSize");
    ok &= abortsWhenCalled("NSTableViewCurrentRowSizeStyle");
    ok &= abortsWhenCalled("_nsBeginNSPSupport");
    EXPECT(ok, "every private function is exported and aborts when called");

    // A notification name Notes binds next to the style function.
    NSString *const *note = (NSString *const *) dlsym(RTLD_DEFAULT, "NSTableViewCurrentRowSizeStyleDidChange");
    EXPECT(note != NULL && [*note length] > 0, "NSTableViewCurrentRowSizeStyleDidChange is an exported non-empty string");
    EXPECT(![*note isEqualToString: @"NSTableViewSelectionDidChangeNotification"], "it differs from the selection notification");
    [pool drain];
    printf("PASS: private AppKit functions fail loudly\n");
    return 0;
}
