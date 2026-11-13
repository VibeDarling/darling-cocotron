// The Add and Remove template images are not installed with AppKit, so +imageNamed: draws them; the
// "plus" and "minus" system symbols share that artwork, and a nib image resource that names a system
// symbol resolves to an image instead of an empty one.
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

// Alpha of the pixel at (x, y), counted from the bottom left, after drawing the image into a 12 x 12 bitmap.
static unsigned char alphaAt(NSImage *image, int x, int y)
{
    unsigned char pixels[12 * 12 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef port = CGBitmapContextCreate(pixels, 12, 12, 8, 48, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    expect(port != NULL, @"bitmap context");
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:port flipped:NO]];
    [image drawInRect:NSMakeRect(0, 0, 12, 12) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    [NSGraphicsContext setCurrentContext:nil];
    CGContextRelease(port);
    return pixels[((11 - y) * 12 + x) * 4 + 3];
}

@interface TestResource : NSObject <NSCoding>
@property (copy) NSString *resourceName;
@end
@implementation TestResource
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:@"NSImage" forKey:@"NSClassName"];
    [coder encodeObject:self.resourceName forKey:@"NSResourceName"];
}
- (id)initWithCoder:(NSCoder *)coder { return [self init]; }
@end

static id decodeResource(NSString *name)
{
    TestResource *resource = [[TestResource new] autorelease];
    resource.resourceName = name;
    NSMutableData *archive = [NSMutableData data];
    NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:archive] autorelease];
    [archiver encodeObject:resource forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:archive] autorelease];
    [unarchiver setClass:NSClassFromString(@"NSCustomResource") forClassName:@"TestResource"];
    return [unarchiver decodeObjectForKey:@"root"];
}

int main(void)
{
    @autoreleasepool
    {
        NSImage *add = [NSImage imageNamed:NSImageNameAddTemplate];
        NSImage *remove = [NSImage imageNamed:NSImageNameRemoveTemplate];
        expect(add != nil && remove != nil, @"the Add and Remove template images are available");
        expect([add isTemplate] && [remove isTemplate], @"they are template images");
        expect([NSImage imageNamed:NSImageNameAddTemplate] == add, @"+imageNamed: returns the shared image");
        expect(NSEqualSizes(add.size, NSMakeSize(12, 12)), @"12 x 12 points");

        expect(alphaAt(add, 6, 6) > 128 && alphaAt(remove, 6, 6) > 128, @"both have ink at the center");
        expect(alphaAt(add, 6, 2) > 128, @"Add has a vertical bar");
        expect(alphaAt(remove, 6, 2) == 0, @"Remove has no vertical bar");
        expect(alphaAt(add, 2, 6) > 128 && alphaAt(remove, 2, 6) > 128, @"both have a horizontal bar");
        expect(alphaAt(add, 0, 0) == 0, @"the corner is clear");

        NSImage *plus = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:@"Add"];
        NSImage *minus = [NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:@"Remove"];
        expect(plus != add && minus != remove, @"a symbol image is its own copy");
        expect([[plus name] isEqualToString:@"plus"] && [[minus name] isEqualToString:@"minus"] && [NSImage imageNamed:@"plus"] == nil,
               @"a symbol image has its own, unregistered name");
        expect([plus.accessibilityDescription isEqualToString:@"Add"], @"the description is kept");
        expect(alphaAt(plus, 6, 2) > 128 && alphaAt(minus, 6, 2) == 0 && alphaAt(minus, 2, 6) > 128,
               @"plus and minus use the drawn artwork");

        NSImage *other = [NSImage imageWithSystemSymbolName:@"gearshape.fill" accessibilityDescription:nil];
        expect(other != nil && alphaAt(other, 6, 6) == 0, @"another symbol stays the generic placeholder");

        expect([NSImage imageNamed:@"NSNoSuchSystemImage"] == nil, @"unknown names stay nil");

        NSImage *fromNib = decodeResource(@"minus");
        expect([fromNib isKindOfClass:[NSImage class]] && alphaAt(fromNib, 2, 6) > 128 && alphaAt(fromNib, 6, 2) == 0,
               @"a nib resource named minus resolves to the minus image");
        NSImage *symbolFromNib = decodeResource(@"gearshape.fill");
        expect([symbolFromNib isKindOfClass:[NSImage class]] && symbolFromNib.size.width > 0,
               @"a nib resource naming another symbol has a size");
        NSImage *app = decodeResource(@"AMSMIDIWindowIcon");
        expect([app isKindOfClass:[NSImage class]] && app.size.width == 0 && app.size.height == 0,
               @"a nib resource that is not a symbol name stays an empty missing image");
        NSImage *named = decodeResource(@"NSAddTemplate");
        expect(alphaAt(named, 6, 2) > 128, @"a nib resource named NSAddTemplate resolves to the Add image");

        NSLog(@"PASS: Add and Remove template images");
    }
    return 0;
}
