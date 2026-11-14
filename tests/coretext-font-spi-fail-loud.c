#include <dlfcn.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

// Eleven CoreText functions that Font Book imports. Seven are private and no permitted source documents their
// arguments or results; four are documented but Cocotron has no font registry to answer from. Each is exported so
// that the import binds, and a call prints its name and aborts. Each call runs in a child process so that the
// abort can be observed.
static const char *names[] = {
    "CTFontCopyStringForGlyph", "CTFontDescriptorCopyDownloadableFontAttributesForRequests",
    "CTFontDescriptorCopyName", "CTFontDescriptorIsVisible", "CTFontGetDefaultAscent",
    "CTFontManagerCompareFontDescriptors2", "CTFontManagerValidateFonts",
    // documented functions with no registry behind them yet
    "CTFontManagerIsSupportedFont", "CTFontManagerGetScopeForURL", "CTFontManagerEnableFontDescriptors",
    "CTFontManagerUnregisterFontURLs",
};

static int check(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) { printf("FAIL: %s: the symbol is not exported\n", name); return 1; }
    int fds[2];
    if (pipe(fds) != 0) { printf("FAIL: pipe\n"); return 1; }
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        dup2(fds[1], STDERR_FILENO);
        close(fds[0]); close(fds[1]);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function();
        _exit(0);
    }
    close(fds[1]);
    char message[256] = {0};
    read(fds[0], message, sizeof message - 1);
    close(fds[0]);
    int status = 0;
    waitpid(child, &status, 0);
    if (!(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT)) { printf("FAIL: %s: a call did not abort\n", name); return 2; }
    if (strstr(message, name) == NULL) { printf("FAIL: %s: the message does not name the function\n", name); return 3; }
    return 0;
}

int main(void) {
    for (unsigned i = 0; i < sizeof names / sizeof names[0]; i++) {
        int rc = check(names[i]);
        if (rc != 0) return rc;
    }
    printf("PASS: CoreText private functions fail loudly\n");
    return 0;
}
