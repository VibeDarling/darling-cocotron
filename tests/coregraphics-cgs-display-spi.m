#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreGraphics/CGSDisplaySPI.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// CGSMainDisplayID and CGSGetOnlineDisplayList are the window-server spellings of CGMainDisplayID and
// CGGetOnlineDisplayList (prototypes from WebKit's CoreGraphicsSPI.h and CGSInternal's CGSDisplays.h): they
// answer exactly what the public functions answer. A headless guest has the single display 1, which a constant
// would also return, so the test first swaps in a display model with two screens (ids 7 and 9).
@interface MockScreen : NSObject {
    CGDirectDisplayID _id;
}
- (instancetype) initWithID: (CGDirectDisplayID) displayID;
@end
@implementation MockScreen
- (instancetype) initWithID: (CGDirectDisplayID) displayID {
    if ((self = [super init])) _id = displayID;
    return self;
}
- (CGDirectDisplayID) cgDirectDisplayID { return _id; }
- (NSRect) frame { return NSMakeRect(_id * 100, 0, 800, 600); }
@end

static NSArray *mockScreens;
@interface MockDisplay : NSObject
@end
@implementation MockDisplay
- (NSArray *) screens { return mockScreens; }
@end
static id mockDisplay;
static id mockCurrentDisplay(id self, SEL _cmd) { return mockDisplay; }

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    EXPECT(CGSMainDisplayID() == CGMainDisplayID(), "the main display ids agree without a display model");

    mockScreens = [[NSArray alloc] initWithObjects: [[[MockScreen alloc] initWithID: 7] autorelease],
                                                   [[[MockScreen alloc] initWithID: 9] autorelease], nil];
    mockDisplay = [MockDisplay new];
    Class displayClass = NSClassFromString(@"NSDisplay");
    EXPECT(displayClass != Nil, "NSDisplay exists");
    class_replaceMethod(object_getClass(displayClass), @selector(currentDisplay), (IMP) mockCurrentDisplay, "@@:");

    EXPECT(CGMainDisplayID() == 7, "the public function reads the display model");
    EXPECT(CGSMainDisplayID() == 7, "the CGS main display is the model's main display");

    CGDirectDisplayID expected[8], got[8];
    uint32_t expectedCount = 99, gotCount = 77;
    memset(expected, 0, sizeof expected);
    memset(got, 0, sizeof got);
    EXPECT(CGGetOnlineDisplayList(8, expected, &expectedCount) == kCGErrorSuccess, "the public list succeeds");
    EXPECT(expectedCount == 2 && expected[0] == 7 && expected[1] == 9, "the public list is the model's");
    EXPECT(CGSGetOnlineDisplayList(8, got, &gotCount) == kCGErrorSuccess, "the CGS list succeeds");
    EXPECT(gotCount == 2, "the CGS count is the model's");
    EXPECT(memcmp(got, expected, sizeof got) == 0, "the CGS ids are the public ids");

    CGDirectDisplayID one[1] = { 0 };
    uint32_t oneCount = 0;
    EXPECT(CGSGetOnlineDisplayList(1, one, &oneCount) == kCGErrorSuccess && oneCount == 2 && one[0] == 7, "a short buffer takes the first display and reports the full count");
    [pool drain];
    printf("PASS: CGS display SPI\n");
    return 0;
}
