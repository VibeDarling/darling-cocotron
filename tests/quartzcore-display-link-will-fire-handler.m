#import <Foundation/Foundation.h>
#import <QuartzCore/CADisplayLink.h>
#include <stdlib.h>

// Mac Catalyst frameworks send +[CADisplayLink setWillFireHandler:]; it is private and
// undocumented, so the block is kept and released but never called.
@interface CADisplayLink (WillFireHandlerPrivate)
+ (void)setWillFireHandler:(id)handler;
@end

static int failures;
static BOOL tokenDeallocated;
static int calls;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

@interface Token : NSObject
@end
@implementation Token
- (void)dealloc
{
    tokenDeallocated = YES;
    [super dealloc];
}
@end

@interface Target : NSObject
{
@public
    int frames;
}
- (void)frame:(CADisplayLink *)link;
@end
@implementation Target
- (void)frame:(CADisplayLink *)link { frames++; }
@end

int main(void)
{
    @autoreleasepool
    {
        expect([CADisplayLink respondsToSelector:@selector(setWillFireHandler:)],
               @"CADisplayLink answers +setWillFireHandler:");

        Token *token = [[Token alloc] init];
        void (^handler)(void) = ^{ (void)token; calls++; };
        [CADisplayLink setWillFireHandler:handler];
        [token release];
        expect(!tokenDeallocated, @"the handler is copied and kept");

        Target *target = [[Target alloc] init];
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:target selector:@selector(frame:)];
        [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
        [link invalidate];
        expect(target->frames > 0, @"the display link still fires its target");
        expect(calls == 0, @"the handler is never called, its signature is unknown");
        [target release];

        [CADisplayLink setWillFireHandler:nil];
        expect(tokenDeallocated, @"clearing the handler releases the block");

        if (failures == 0)
            NSLog(@"PASS: CADisplayLink +setWillFireHandler:");
    }
    return failures == 0 ? 0 : 1;
}
