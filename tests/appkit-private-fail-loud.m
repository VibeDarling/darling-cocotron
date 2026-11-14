#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// NSColorEffectiveUserAccentColor is a private AppKit function that stock applications import. It is exported so
// that they bind; nothing public documents its result, so a call aborts instead of returning an invented color.
int main(void) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, "NSColorEffectiveUserAccentColor");
    EXPECT(function != NULL, "NSColorEffectiveUserAccentColor is exported");
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function();
        _exit(0);
    }
    int status = 0;
    EXPECT(waitpid(child, &status, 0) == child, "the child is reaped");
    EXPECT(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, "the call aborts");
    printf("PASS: private AppKit function fails loudly\n");
    return 0;
}
