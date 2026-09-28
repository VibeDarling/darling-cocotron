#import "../AppKit/NSImageDrawingCache.m"
#include <assert.h>
#include <stdio.h>

static unsigned destroyed;
@interface CacheLifetimeToken : NSObject @end
@implementation CacheLifetimeToken
- (void)dealloc { ++destroyed; [super dealloc]; }
@end

int main(void) {
    setbuf(stdout, NULL);
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    NSImageDrawingCache *cache=[NSImageDrawingCache new];
    for (unsigned i=0;i<4;++i) {
        NSNumber *key=[NSNumber numberWithUnsignedInt:i];
        assert([cache setRepresentation:key forKey:key byteCost:1]);
    }
    assert([[cache representationForKey:@0] isEqual:@0]);
    assert([cache setRepresentation:@4 forKey:@4 byteCost:1]);
    assert([cache representationForKey:@1]==nil); // 0 was promoted.
    assert([[cache representationForKey:@0] isEqual:@0]);
    assert([cache setRepresentation:@"replacement" forKey:@0 byteCost:1]);
    assert([[cache representationForKey:@0] isEqual:@"replacement"]);
    assert([cache setRepresentation:@"large" forKey:@"large" byteCost:16*1024*1024]);
    assert([cache representationForKey:@0]==nil);
    assert(![cache setRepresentation:@"too large" forKey:@"overflow" byteCost:NSUIntegerMax]);
    assert([[cache representationForKey:@"large"] isEqual:@"large"]);
    [cache removeAllObjects];
    assert([cache representationForKey:@"large"]==nil);
    NSMutableString *key=[NSMutableString stringWithString:@"original"];
    assert([cache setRepresentation:@"value" forKey:key byteCost:1]);
    [key appendString:@" changed"];
    assert([[cache representationForKey:@"original"] isEqual:@"value"]);
    assert([cache representationForKey:key]==nil);
    [cache removeAllObjects];
    for (unsigned i=0;i<5;++i) {
        CacheLifetimeToken *token=[CacheLifetimeToken new];
        assert([cache setRepresentation:token forKey:@(i) byteCost:1]);
        [token release];
    }
    // Eviction must relinquish ownership even before the caller's pool drains.
    assert(destroyed==1);
    assert([cache representationForKey:@1]!=nil);
    CacheLifetimeToken *last=[CacheLifetimeToken new];
    assert([cache setRepresentation:last forKey:@5 byteCost:1]);
    [last release];
    assert(destroyed==2 && [cache representationForKey:@2]==nil);
    assert([cache setRepresentation:@"replacement" forKey:@1 byteCost:1]);
    assert(destroyed==3);
    [cache removeAllObjects];
    assert(destroyed==6);
    CacheLifetimeToken *owned=[CacheLifetimeToken new];
    assert([cache setRepresentation:owned forKey:@"owned" byteCost:1]);
    [owned release];
    // Replacement with a borrowed reference must retain it before removing
    // the old entry that owns that reference.
    assert([cache setRepresentation:[cache representationForKey:@"owned"]
                            forKey:@"owned" byteCost:1]);
    assert(destroyed==6);
    [cache release];
    assert(destroyed==7);
    [pool release];
    puts("PASS: drawing cache LRU, replacement, byte bound, overflow rejection, invalidation, key copying and prompt ownership release");
    return 0;
}
