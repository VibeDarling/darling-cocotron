#import "../AppKit/NSImageDrawingCache.m"
#include <assert.h>
#include <stdio.h>

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
    [cache release];
    [pool release];
    puts("PASS: drawing cache LRU, replacement, byte bound, overflow rejection, invalidation and key copying");
    return 0;
}
