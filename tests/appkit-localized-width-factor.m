// Link with candidate AppKit; no windows are needed.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

extern void _NSLocalizedUserInterfaceWidthFactor(void);

// The function is exported so that a client binds, and a call fails loudly (SIGABRT) rather than
// returning an invented width factor.
int main(void) {
    @autoreleasepool {
        expect(dlsym(RTLD_DEFAULT, "_NSLocalizedUserInterfaceWidthFactor") != NULL, @"the symbol is exported");
        pid_t child = fork();
        if (child == 0) {
            freopen("/dev/null", "w", stderr);
            _NSLocalizedUserInterfaceWidthFactor();
            _exit(0);
        }
        int status = 0;
        waitpid(child, &status, 0);
        expect(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, @"a call aborts");
        NSLog(@"PASS: _NSLocalizedUserInterfaceWidthFactor fails loudly");
    }
    return 0;
}
