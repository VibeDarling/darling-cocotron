#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// NSAccessibilityPointInView (public SDK header NSAccessibility.h): given a view and a point in that view's
// coordinates, returns the point in screen coordinates. The expected numbers below are worked out by hand from a
// borderless window whose content area is its frame: screen = window origin + the view's origin in the window
// + the point.
//
// NSAccessibilityUnregisterUniqueIdForUIElement is private, so it is exported and a call aborts.
typedef NSPoint (*PointInView)(NSView *, NSPoint);

static int abortsWhenCalled(const char *name) {
    void (*function)(id) = (void (*)(id)) dlsym(RTLD_DEFAULT, name);
    if (function == NULL) {
        return -1;
    }
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        function(nil);
        _exit(0);
    }
    int status = 0;
    if (waitpid(child, &status, 0) != child) {
        return 0;
    }
    return WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT;
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    PointInView pointInView = (PointInView) dlsym(RTLD_DEFAULT, "NSAccessibilityPointInView");
    EXPECT(pointInView != NULL, "NSAccessibilityPointInView is exported");

    NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 200, 300, 200)
                                                   styleMask: NSWindowStyleMaskBorderless
                                                     backing: NSBackingStoreBuffered
                                                       defer: YES];
    EXPECT(NSEqualRects([window frame], NSMakeRect(100, 200, 300, 200)), "the borderless window frame is its content rect");
    NSView *outer = [[NSView alloc] initWithFrame: NSMakeRect(10, 20, 100, 100)];
    NSView *inner = [[NSView alloc] initWithFrame: NSMakeRect(5, 7, 50, 50)];
    [[window contentView] addSubview: outer];
    [outer addSubview: inner];

    NSPoint p = pointInView(outer, NSMakePoint(3, 4));
    EXPECT(p.x == 113 && p.y == 224, "a point in a view of the content view: window origin + view origin + point");
    p = pointInView(inner, NSMakePoint(1, 2));
    EXPECT(p.x == 116 && p.y == 229, "a point in a nested view adds both view origins");
    p = pointInView([window contentView], NSMakePoint(0, 0));
    EXPECT(p.x == 100 && p.y == 200, "the content view's origin is the window origin");

    [window setFrameOrigin: NSMakePoint(500, 600)];
    p = pointInView(outer, NSMakePoint(3, 4));
    EXPECT(p.x == 513 && p.y == 624, "the result follows the window when it moves");

    // The header says nothing about a view that is in no window or a nil view. GUESS (see NSAccessibility.m): an
    // unwindowed view answers in the coordinates of the topmost view of its superview chain, with no screen offset,
    // and a nil view returns the point unchanged.
    NSView *loose = [[NSView alloc] initWithFrame: NSMakeRect(10, 20, 100, 100)];
    NSView *looseChild = [[NSView alloc] initWithFrame: NSMakeRect(5, 7, 10, 10)];
    [loose addSubview: looseChild];
    p = pointInView(looseChild, NSMakePoint(1, 1));
    EXPECT(p.x == 6 && p.y == 8, "a nested view under an unwindowed root answers in the root's coordinates");
    p = pointInView(loose, NSMakePoint(3, 4));
    EXPECT(p.x == 3 && p.y == 4, "an unwindowed root answers with the point unchanged");
    p = pointInView(nil, NSMakePoint(3, 4));
    EXPECT(p.x == 3 && p.y == 4, "a nil view returns the point unchanged");

    int aborts = abortsWhenCalled("NSAccessibilityUnregisterUniqueIdForUIElement");
    EXPECT(aborts != -1, "NSAccessibilityUnregisterUniqueIdForUIElement is exported");
    EXPECT(aborts == 1, "NSAccessibilityUnregisterUniqueIdForUIElement aborts when called");

    [looseChild release];
    [loose release];
    [inner release];
    [outer release];
    [window release];
    [pool drain];
    printf("PASS: accessibility point in view\n");
    return 0;
}
