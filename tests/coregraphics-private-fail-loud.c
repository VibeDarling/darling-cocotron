#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

// Private functions that stock applications import (Maps, ColorSync Utility, QuickTime Player, Calendar, Font Book). No permitted
// source documents their arguments or results, so a call prints the name and aborts. Each is called in a
// child with its stderr piped; the pipe is read to EOF, so a long message cannot be cut short.
static int check(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) { printf("FAIL: %s is not exported\n", name); return 1; }
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
    char message[512] = {0};
    size_t length = 0;
    for (;;) {
        char chunk[128];
        ssize_t got = read(fds[0], chunk, sizeof chunk);
        if (got <= 0) break;
        for (ssize_t i = 0; i < got && length < sizeof message - 1; i++) message[length++] = chunk[i];
    }
    close(fds[0]);
    int status = 0;
    waitpid(child, &status, 0);
    if (!(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT)) { printf("FAIL: %s did not abort\n", name); return 1; }
    if (strstr(message, name) == NULL) { printf("FAIL: the message of %s does not name it\n", name); return 1; }
    return 0;
}

int main(void) {
    static const char *names[] = {
        "CGBitmapGetAlignedBytesPerRow", "CGBitmapContextCreateWithDictionary", "CGSCopySpaces",
        "CGContextGetLineDashPattern", "CGStyleRetain", "CGStyleEqualToStyle", "CGSDisableUpdateToken",
        "CGSReenableUpdateToken", "CGSSetWindowTransform", "CGFontGetParserFont",
    };
    int failures = 0;
    for (size_t i = 0; i < sizeof names / sizeof names[0]; i++) failures += check(names[i]);
    if (failures == 0) printf("PASS: the private CoreGraphics names fail loudly\n");
    return failures ? 1 : 0;
}
