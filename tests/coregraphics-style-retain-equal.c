#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

// CGStyleRetain and CGStyleEqualToStyle (Calendar) on Cocotron's style stand-in. Expected values are what a real Mac
// answered for its own shadow styles (macOS 26.1, probe 11 section 6, darling_probe11.txt line 73): retain returns
// its argument; equal for the same object and for NULL, NULL; not equal for an object and NULL. The stand-in does not
// keep a style's parameters, so two different objects cannot be compared and the call aborts with a message that
// names the function instead of answering. The test also retains and releases so a double free would show.
typedef void *(*CreateFn)(void *, void *);
typedef void *(*RetainFn)(void *);
typedef void (*ReleaseFn)(void *);
typedef bool (*EqualFn)(void *, void *);

int main(void) {
    CreateFn create = (CreateFn) dlsym(RTLD_DEFAULT, "CGStyleCreateShadow");
    RetainFn retain = (RetainFn) dlsym(RTLD_DEFAULT, "CGStyleRetain");
    ReleaseFn release = (ReleaseFn) dlsym(RTLD_DEFAULT, "CGStyleRelease");
    EqualFn equal = (EqualFn) dlsym(RTLD_DEFAULT, "CGStyleEqualToStyle");
    if (create == NULL || retain == NULL || release == NULL || equal == NULL) { printf("FAIL: the style functions are exported\n"); return 1; }
    int failures = 0;
    void *a = create(NULL, NULL), *b = create(NULL, NULL);
    if (a == NULL || b == NULL) { printf("FAIL: styles are created\n"); return 1; }
    if (retain(a) != a) { printf("FAIL: retain returns its argument\n"); failures++; }
    if (!equal(a, a)) { printf("FAIL: a style equals itself\n"); failures++; }
    if (equal(a, NULL) || equal(NULL, a)) { printf("FAIL: a style does not equal NULL\n"); failures++; }
    if (!equal(NULL, NULL)) { printf("FAIL: NULL equals NULL\n"); failures++; }
    release(a);  /* back to one reference: still alive */
    if (!equal(a, a)) { printf("FAIL: a style survives a retain and one release\n"); failures++; }
    release(a);
    release(NULL);

    fflush(stdout);
    int fds[2];
    if (pipe(fds) != 0) return 1;
    pid_t child = fork();
    if (child == 0) {
        dup2(fds[1], STDERR_FILENO); close(fds[0]); close(fds[1]);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        equal(b, create(NULL, NULL));
        _exit(0);
    }
    close(fds[1]);
    char message[256] = {0}; size_t length = 0; char chunk[64]; ssize_t got;
    while ((got = read(fds[0], chunk, sizeof chunk)) > 0)
        for (ssize_t i = 0; i < got && length < sizeof message - 1; i++) message[length++] = chunk[i];
    close(fds[0]);
    int status = 0;
    waitpid(child, &status, 0);
    if (!(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT) || strstr(message, "CGStyleEqualToStyle") == NULL) {
        printf("FAIL: two different styles abort loudly, naming the function\n"); failures++;
    }
    release(b);
    if (failures == 0) printf("PASS: CGStyleRetain, CGStyleEqualToStyle\n");
    return failures ? 1 : 0;
}
