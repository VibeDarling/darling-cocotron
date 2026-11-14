#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Private AppKit function that TV imports. It is exported so the application binds; nothing public documents its
// result, so a call prints its name and aborts instead of inventing one. The child's stderr is read to EOF before
// the status is collected.
static int failsLoudly(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) {
        printf("FAIL: %s is not exported\n", name);
        return 0;
    }
    int fds[2];
    if (pipe(fds) != 0) {
        printf("FAIL: pipe\n");
        return 0;
    }
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        close(fds[0]);
        dup2(fds[1], 2);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function();
        _exit(0);
    }
    close(fds[1]);
    char text[512];
    size_t length = 0;
    ssize_t count;
    while ((count = read(fds[0], text + length, sizeof text - 1 - length)) > 0) {
        length += (size_t) count;
    }
    close(fds[0]);
    text[length] = 0;
    int status = 0;
    if (waitpid(child, &status, 0) != child || !WIFSIGNALED(status) || WTERMSIG(status) != SIGABRT) {
        printf("FAIL: calling %s does not abort\n", name);
        return 0;
    }
    if (strstr(text, name) == NULL || strstr(text, "not implemented") == NULL) {
        printf("FAIL: calling %s does not say so on stderr: %s\n", name, text);
        return 0;
    }
    return 1;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    EXPECT(failsLoudly("_NSCenteredRectForImage"), "_NSCenteredRectForImage is exported, prints its name and aborts");
    [pool drain];
    printf("PASS: batch 4 private AppKit function fails loudly\n");
    return 0;
}
