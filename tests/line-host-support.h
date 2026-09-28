// Host adapters for executing candidate sources, not the Darling CF runtime.
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdint.h>
#include <assert.h>
typedef NSInteger CFIndex;
typedef NSUInteger CFTypeID;
typedef id CFTypeRef, CFDictionaryRef, CFMutableDictionaryRef, CFArrayRef, CFMutableArrayRef;
typedef id CFAttributedStringRef, CFDataRef, CFNumberRef;
typedef NSString *CFStringRef;
typedef NSMutableString *CFMutableStringRef;
typedef unichar UniChar;
typedef unsigned char UInt8;
typedef struct { CFIndex location,length; } CFRange;
typedef NSPoint CGPoint;
typedef NSSize CGSize;
typedef NSRect CGRect;
typedef struct { double a,b,c,d,tx,ty; } CGAffineTransform;
typedef uint16_t CGGlyph;
typedef id CTLineRef, CTRunRef, CTFontRef, CGContextRef;
typedef unsigned CTLineTruncationType, CTLineBoundsOptions, CTRunStatus;
static CFRange CFRangeMake(CFIndex location,CFIndex length) { return (CFRange){location,length}; }
#define CGPointMake NSMakePoint
#define CGRectMake NSMakeRect
#define CGSizeZero NSZeroSize
#define CGAffineTransformIdentity ((CGAffineTransform){1,0,0,1,0,0})
#define kCFNotFound NSNotFound
#define kCFAllocatorDefault NULL
#define CFSTR(s) @s
static int kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks, kCFTypeArrayCallBacks;
enum { kCFNumberCFIndexType, kCFNumberCGFloatType, kCFStringNormalizationFormC, kCTFontOrientationDefault, kCTRunStatusNoStatus };
const CFStringRef kCTFontAttributeName = @"font";
static id CFRetain(id value) { return [value retain]; }
static void CFRelease(id value) { [value release]; }
static id CFDictionaryCreateMutable(void *a,CFIndex n,void *k,void *v) { return [NSMutableDictionary new]; }
static id CFDictionaryCreateMutableCopy(void *a,CFIndex n,id d) { return [d mutableCopy]; }
static id CFDictionaryGetValue(id d,id k) { return [d objectForKey:k]; }
static void CFDictionarySetValue(id d,id k,id v) { [d setObject:v forKey:k]; }
static id CFArrayCreateMutable(void *a,CFIndex n,void *c) { return [NSMutableArray new]; }
static void CFArrayAppendValue(id a,id v) { [a addObject:v]; }
static CFIndex CFArrayGetCount(id a) { return [a count]; }
static id CFArrayGetValueAtIndex(id a,CFIndex i) { return [a objectAtIndex:i]; }
static id CFAttributedStringCreateCopy(void *a,id s) { return [s copy]; }
static CFIndex CFAttributedStringGetLength(id s) { return [s length]; }
static id CFAttributedStringGetString(id s) { return [s string]; }
static id CFAttributedStringGetAttributes(id s,CFIndex i,CFRange *range) {
    NSRange native; id result=[s attributesAtIndex:i effectiveRange:range ? &native : NULL];
    if (range) *range=CFRangeMake(native.location,native.length); return result;
}
static CFIndex CFStringGetLength(id s) { return [s length]; }
static void CFStringGetCharacters(id s,CFRange range,UniChar *out) { [s getCharacters:out range:NSMakeRange(range.location,range.length)]; }
static CFRange CFStringGetRangeOfComposedCharactersAtIndex(id s,CFIndex i) {
    NSRange r=[s rangeOfComposedCharacterSequenceAtIndex:i]; return CFRangeMake(r.location,r.length);
}
static id CFStringCreateWithSubstring(void *a,id s,CFRange r) { return [[s substringWithRange:NSMakeRange(r.location,r.length)] retain]; }
static id CFStringCreateMutableCopy(void *a,CFIndex n,id s) { return [s mutableCopy]; }
static void CFStringNormalize(id s,int form) { [s setString:[s precomposedStringWithCanonicalMapping]]; }
static id CFDataCreate(void *a,const UInt8 *bytes,CFIndex n) { return [[NSData alloc] initWithBytes:bytes length:n]; }
static const UInt8 *CFDataGetBytePtr(id data) { return [data bytes]; }
static id CFNumberCreate(void *a,int type,const void *value) {
    return type == kCFNumberCFIndexType ? [[NSNumber alloc] initWithLong:*(const CFIndex *)value]
        : [[NSNumber alloc] initWithDouble:*(const CGFloat *)value];
}
static bool CFNumberGetValue(id number,int type,void *out) {
    if (type == kCFNumberCFIndexType) *(CFIndex *)out = [number longValue];
    else *(CGFloat *)out = [number doubleValue];
    return true;
}
typedef struct { void *isa; CFTypeID type; } CFRuntimeBase;
typedef struct { int version; const char *name; void *init,*copy; void (*finalize)(CFTypeRef); void *equal,*hash,*format,*debug; } CFRuntimeClass;
static const CFRuntimeClass *classes[16];
static int registeredClasses, liveObjects, allocationCount, failAllocation;
@interface HostRuntimeObject : NSObject { @public CFTypeID type; id storage; } @end
@implementation HostRuntimeObject
- (void)dealloc { classes[type-100]->finalize(self); liveObjects--; [super dealloc]; }
@end
static CFTypeID _CFRuntimeRegisterClass(const CFRuntimeClass *c) {
    assert(registeredClasses < 16); classes[registeredClasses] = c; return 100 + registeredClasses++;
}
static CFTypeRef _CFRuntimeCreateInstance(void *allocator,CFTypeID type,CFIndex extra,void *category) {
    if (++allocationCount == failAllocation) return nil;
    HostRuntimeObject *o = [HostRuntimeObject new]; o->type = type; liveObjects++; return o;
}
static CFTypeID CFGetTypeID(id object) { return ((HostRuntimeObject *)object)->type; }
static bool CTFontGetGlyphsForCharacters(id font,const UniChar *c,CGGlyph *g,CFIndex n) {
    for (CFIndex i=0;i<n;i++) g[i]=c[i]; return true;
}
static double CTFontGetAdvancesForGlyphs(id font,int orientation,const CGGlyph *g,CGSize *a,CFIndex n) {
    double width=[font doubleValue]; for (CFIndex i=0;i<n;i++) a[i]=NSMakeSize(width,0); return n*width;
}
static CGFloat CTFontGetAscent(id f) { return 8; }
static CGFloat CTFontGetDescent(id f) { return 2; }
static CGFloat CTFontGetLeading(id f) { return 1; }
static id CTFontCreateForString(id f,id s,CFRange r) { return [f retain]; }
static void CTFontDrawGlyphs(id f,const CGGlyph *g,const CGPoint *p,size_t n,id context) {}
