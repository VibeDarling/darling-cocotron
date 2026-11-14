#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGSAddWindowsToSpaces is private and QuickTime Player imports it. Cocotron has no spaces, so the call is a
// no-op that succeeds and does not read its arguments (GUESS: no permitted source gives the prototype). It
// must be exported and callable with a window and space list, with an empty list and with NULLs without
// aborting, and it names itself on stderr on the first call only, so that it is never silent.
static int run(int (*add)(int, CFArrayRef, CFArrayRef), char *message, size_t size) {
    int fds[2];
    if (pipe(fds) != 0) return -1;
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        dup2(fds[1], STDERR_FILENO);
        close(fds[0]); close(fds[1]);
        int window = 42, space = 1;
        CFNumberRef windowNumber = CFNumberCreate(NULL, kCFNumberIntType, &window);
        CFNumberRef spaceNumber = CFNumberCreate(NULL, kCFNumberIntType, &space);
        CFArrayRef windows = CFArrayCreate(NULL, (const void *[]) { windowNumber }, 1, &kCFTypeArrayCallBacks);
        CFArrayRef spaces = CFArrayCreate(NULL, (const void *[]) { spaceNumber }, 1, &kCFTypeArrayCallBacks);
        CFArrayRef none = CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks);
        int bad = add(1, windows, spaces) != 0 || add(1, none, none) != 0 || add(0, NULL, NULL) != 0;
        _exit(bad ? 3 : 0);
    }
    close(fds[1]);
    // Read to EOF (the child's exit), so that a print arriving late is still seen.
    size_t used = 0;
    ssize_t n;
    while (used < size - 1 && (n = read(fds[0], message + used, size - 1 - used)) > 0) used += (size_t) n;
    message[used] = 0;
    close(fds[0]);
    int status = 0;
    waitpid(child, &status, 0);
    return WIFEXITED(status) ? WEXITSTATUS(status) : -2;
}

int main(void) {
    int (*add)(int, CFArrayRef, CFArrayRef) = (int (*)(int, CFArrayRef, CFArrayRef)) dlsym(RTLD_DEFAULT, "CGSAddWindowsToSpaces");
    EXPECT(add != NULL, "CGSAddWindowsToSpaces is exported");
    char message[512];
    EXPECT(run(add, message, sizeof message) == 0, "every call succeeds with 0 and nothing aborts");
    const char *first = strstr(message, "CGSAddWindowsToSpaces");
    EXPECT(first != NULL, "the first call names the function on stderr");
    EXPECT(strstr(first + 1, "CGSAddWindowsToSpaces") == NULL, "three calls print the name once");
    printf("PASS: CGSAddWindowsToSpaces\n");
    return 0;
}
