#import <AppKit/AppKit.h>
#include <stdlib.h>

// Private selector, declared only here so the test compiles, and fails at run
// time, without the addition. GUESS / NEEDS-REAL-MAC: the real color is unknown.
@interface NSColor (SelectionMaterialTintProbe)
+ (NSColor *) _selectionMaterialTintColor;
@end

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        expect([NSColor respondsToSelector:@selector(_selectionMaterialTintColor)],
               @"+_selectionMaterialTintColor is not implemented");
        NSColor *tint = [NSColor _selectionMaterialTintColor];
        expect(tint != nil, @"tint color is nil");
        expect([tint isKindOfClass:[NSColor class]], @"tint color is not an NSColor");

        NSColor *expected = [NSColor selectedContentBackgroundColor];
        expect(expected != nil, @"selectedContentBackgroundColor is nil");
        expect([tint isEqual:expected], @"tint is not selectedContentBackgroundColor");
        expect(![tint isEqual:[NSColor controlAccentColor]],
               @"tint equals controlAccentColor, so the check cannot tell the choices apart");

        NSLog(@"PASS");
    }
    return 0;
}
