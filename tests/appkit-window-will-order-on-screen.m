// Link with candidate AppKit; the platform window is replaced by a recorder, so no display is needed.
#import <AppKit/AppKit.h>
#include <objc/runtime.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// Swallows every platform-window message, as a window server that accepts everything would.
@interface NullPlatformWindow : NSObject
@end
@implementation NullPlatformWindow
- (BOOL) respondsToSelector: (SEL) selector { return YES; }
- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    NSMutableString *types = [NSMutableString stringWithString: @"@@:"];
    for (const char *c = sel_getName(selector); *c; c++) {
        if (*c == ':') [types appendString: @"q"];
    }
    return [NSMethodSignature signatureWithObjCTypes: [types UTF8String]];
}
- (void) forwardInvocation: (NSInvocation *) invocation {
    id nothing = nil;
    [invocation setReturnValue: &nothing];
}
@end

@interface TestWindow : NSWindow
@end
@implementation TestWindow
- (id) platformWindow {
    static id platform;
    if (platform == nil) platform = [[NullPlatformWindow alloc] init];
    return platform;
}
@end

@interface Recorder : NSObject
@property(retain) NSMutableArray *names;
@end
@implementation Recorder
- (void) note: (NSNotification *) notification { [self.names addObject: [notification name]]; }
@end

// NSWindowWillOrderOnScreenNotification is posted by a window that is about to become visible, before it does.
int main(void) {
    @autoreleasepool {
        expect([NSWindowWillOrderOnScreenNotification length] > 0, @"the notification name is a non-empty string");

        TestWindow *window = [[TestWindow alloc] initWithContentRect: NSMakeRect(0, 0, 50, 50)
                                                           styleMask: NSWindowStyleMaskTitled
                                                             backing: NSBackingStoreBuffered
                                                               defer: YES];
        Recorder *recorder = [[Recorder alloc] init];
        recorder.names = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver: recorder selector: @selector(note:)
                                                     name: NSWindowWillOrderOnScreenNotification object: window];
        [window orderWindow: NSWindowAbove relativeTo: 0];
        expect([recorder.names count] == 1, @"ordering an invisible window on posts the notification once");
        [window orderWindow: NSWindowAbove relativeTo: 0];
        expect([recorder.names count] == 1, @"ordering a visible window again does not post it");
        [window orderWindow: NSWindowOut relativeTo: 0];
        expect([recorder.names count] == 1, @"ordering a window out does not post it");
        [window orderWindow: NSWindowBelow relativeTo: 0];
        expect([recorder.names count] == 2, @"ordering it on again posts it again");
        [window orderWindow: NSWindowOut relativeTo: 0];
        [window setIsVisible: YES];
        expect([recorder.names count] == 3, @"-setIsVisible:YES posts it too");
        [window setIsVisible: YES];
        expect([recorder.names count] == 3, @"-setIsVisible:YES on a visible window does not post it");
        [[NSNotificationCenter defaultCenter] removeObserver: recorder];
        NSLog(@"PASS: NSWindowWillOrderOnScreenNotification");
    }
    return 0;
}
