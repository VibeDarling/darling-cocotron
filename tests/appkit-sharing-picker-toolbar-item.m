#import <AppKit/AppKit.h>
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

@interface Provider : NSObject <NSSharingServicePickerToolbarItemDelegate>
@end
@implementation Provider
- (NSArray *) itemsForSharingServicePickerToolbarItem: (NSSharingServicePickerToolbarItem *) item {
    return [NSArray arrayWithObject: @"item"];
}
@end

// NSSharingServicePickerToolbarItem (macOS 10.15 documentation): an NSToolbarItem with a delegate. Cocotron has no
// share sheet, so activating it aborts. NSSharingServiceItemProvider is private: the class exists and answers
// nothing beyond NSObject.
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSSharingServicePickerToolbarItem *item = [[NSSharingServicePickerToolbarItem alloc] initWithItemIdentifier: @"share"];
    EXPECT([item isKindOfClass: [NSToolbarItem class]], "it is a toolbar item");
    EXPECT([[item itemIdentifier] isEqualToString: @"share"], "the identifier is kept");
    EXPECT([item delegate] == nil, "no delegate by default");
    Provider *provider = [Provider new];
    [item setDelegate: provider];
    EXPECT([item delegate] == provider, "the delegate round-trips");
    EXPECT([[[item delegate] itemsForSharingServicePickerToolbarItem: item] count] == 1, "the delegate supplies the items");

    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        freopen("/dev/null", "w", stderr);
        setrlimit(RLIMIT_CORE, &(struct rlimit){ 0, 0 });
        [[item target] performSelector: [item action] withObject: item];
        _exit(0);
    }
    int status = 0;
    EXPECT(waitpid(child, &status, 0) == child, "the child is reaped");
    EXPECT(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, "activating the item aborts instead of doing nothing");

    EXPECT([item target] == item && [item action] != NULL, "the item is its own target and action by default");
    NSSharingServicePickerToolbarItem *copy = [item copy];
    EXPECT([copy isKindOfClass: [NSSharingServicePickerToolbarItem class]], "a copy keeps the class");
    EXPECT([copy delegate] == provider, "a copy keeps the delegate");
    EXPECT([copy target] == copy, "a copy activates itself, not the original");
    [copy setTarget: provider];
    [copy setAction: @selector(description)];
    EXPECT([copy target] == provider && [copy action] == @selector(description), "an application-set target and action win");
    [copy release];

    Class providerClass = NSClassFromString(@"NSSharingServiceItemProvider");
    EXPECT(providerClass != Nil, "NSSharingServiceItemProvider exists");
    id instance = [providerClass new];
    EXPECT(instance != nil, "an instance can be created");
    EXPECT(![instance respondsToSelector: @selector(registeredTypeIdentifiers)], "it answers no invented selector");
    [instance release];
    [provider release];
    [item release];
    [pool drain];
    printf("PASS: sharing picker toolbar item\n");
    return 0;
}
