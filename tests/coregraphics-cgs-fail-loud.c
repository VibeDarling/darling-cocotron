#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// Two private window-server functions are exported so that clients bind; nothing public documents their
// results, so a call aborts instead of returning an invented value.
static int aborts(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) return -1;
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        function();
        _exit(0);
    }
    int status = 0;
    waitpid(child, &status, 0);
    return WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT;
}

int main(void) {
    EXPECT(aborts("CGSEventIsAppUnresponsive") == 1, "CGSEventIsAppUnresponsive is exported and aborts");
    EXPECT(aborts("CGSSessionCopyCurrentSessionProperties") == 1, "CGSSessionCopyCurrentSessionProperties is exported and aborts");
    printf("PASS: private CGS functions fail loudly\n");
    return 0;
}
