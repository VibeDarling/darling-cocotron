#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s: %s\n", name, msg); return 1; } } while (0)

// Functions that stock applications import. They are exported so that the applications bind; Cocotron cannot
// answer them (no window server, no ColorSync) and the private ones have no public documentation of their
// results, so a call aborts instead of returning an invented value.
static int aborts(const char *name) {
    void (*function)(void) = (void (*)(void)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) return -1;
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function();
        _exit(0);
    }
    int status = 0;
    if (waitpid(child, &status, 0) != child) return -1;
    return WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT;
}

int main(void) {
    static const char *names[] = {
        "CGWindowListCopyWindowInfo", "CGSSessionCopyAllSessionProperties", "CGWindowContextCreate",
        "CGWindowContextCreateImage", "CGColorSpaceCreateWithColorSyncProfile", "CGColorSpaceCreateWithID",
        "CGSGetOnScreenWindowCount", "CGSGetOnScreenWindowList",
        "CGImageWriteToFile", "CGSDisplayStatusQuery", "CGSCopyDisplayInfoDictionary", "CGSCopyDisplayUUID",
        "CGSGetDisplayModeDescriptionsOfLength", "CGSSecondsSinceLastInputEvent", "CGContextCopyDeviceColorSpace",
        "CGDisplayVisualBell", "CGSGetPerformanceData", "CGSGetWindowTags", "CGSHWCaptureWindowList",
        "CGSSetWindowTags",
    };
    for (unsigned i = 0; i < sizeof names / sizeof names[0]; i++) {
        const char *name = names[i];
        EXPECT(aborts(name) == 1, "is exported and aborts");
    }
    printf("PASS: window-server functions fail loudly\n");
    return 0;
}
