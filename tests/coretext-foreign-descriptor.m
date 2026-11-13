// Links CoreText without AppKit. A descriptor made by another CoreText (the shared cache's, whose methods call the
// CTFontDescriptor functions with self) must not make this CoreText recurse through those methods.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface ForeignDescriptor : NSObject
@end

@implementation ForeignDescriptor
- (id)objectForKey:(id)key { return [(id)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)self, (CFStringRef)key) autorelease]; }
- (id)copyWithZone:(NSZone *)zone { return (id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self); }
@end

// An object that answers -fontAttributes with real attributes, like Cocotron's NSFontDescriptor, is read through it.
@interface DuckDescriptor : NSObject
@end

@implementation DuckDescriptor
- (NSDictionary *)fontAttributes { return @{ (id)kCTFontNameAttribute: @"Duck" }; }
@end

// Named like the cache's class: instances are not asked for their attributes, whatever they answer.
@interface NSCTFontDescriptor : NSObject
@end

@implementation NSCTFontDescriptor
- (NSDictionary *)fontAttributes { return [(id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self) autorelease]; }
@end

int main(void)
{
    @autoreleasepool
    {
        ForeignDescriptor *foreign = [[ForeignDescriptor alloc] init];
        CFTypeRef value = CTFontDescriptorCopyAttribute((CTFontDescriptorRef)foreign, kCTFontNameAttribute);
        expect(value == NULL, @"a foreign descriptor has no attributes here");
        CFDictionaryRef none = CTFontDescriptorCopyAttributes((CTFontDescriptorRef)foreign);
        expect(none != NULL && CFDictionaryGetCount(none) == 0, @"a foreign descriptor copies as empty");
        CFRelease(none);
        CTFontRef font = CTFontCreateWithFontDescriptor((CTFontDescriptorRef)foreign, 12, NULL);
        expect(font != NULL, @"a font can still be made from it");
        CFRelease(font);
        CTFontDescriptorRef derived = CTFontDescriptorCreateCopyWithSymbolicTraits(
                (CTFontDescriptorRef)foreign, kCTFontTraitBold, kCTFontTraitBold);
        expect(derived != NULL && CTFontDescriptorGetSymbolicTraits(derived) == kCTFontTraitBold,
               @"a copy made from it carries the requested traits");
        CFRelease(derived);

        DuckDescriptor *duck = [[DuckDescriptor alloc] init];
        CFTypeRef duckName = CTFontDescriptorCopyAttribute((CTFontDescriptorRef)duck, kCTFontNameAttribute);
        expect(duckName != NULL && CFEqual(duckName, CFSTR("Duck")), @"an object that answers -fontAttributes is read through it");
        CFRelease(duckName);

        NSCTFontDescriptor *cacheLike = [[NSCTFontDescriptor alloc] init];
        CFDictionaryRef cacheNone = CTFontDescriptorCopyAttributes((CTFontDescriptorRef)cacheLike);
        expect(cacheNone != NULL && CFDictionaryGetCount(cacheNone) == 0, @"an instance of the cache's class is not read through its methods");
        CFRelease(cacheNone);
        NSLog(@"coretext-foreign-descriptor: ok");
    }
    return 0;
}
