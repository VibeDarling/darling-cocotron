#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

// CGBitmapContextCreateWithAlpha is exported so that ColorSync Utility binds; no permitted source documents
// its arguments or results, so a call prints the name and aborts instead of making a context from a guess.
int main(void) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, "CGBitmapContextCreateWithAlpha");
    if (function == NULL) { printf("FAIL: the symbol is not exported\n"); return 1; }
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
    int status = 0;
    waitpid(child, &status, 0);
    if (!(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT)) { printf("FAIL: a call did not abort\n"); return 2; }
    if (strstr(message, "CGBitmapContextCreateWithAlpha") == NULL) { printf("FAIL: the message does not name the function\n"); return 3; }
    printf("PASS: CGBitmapContextCreateWithAlpha fails loudly\n");
    return 0;
}
