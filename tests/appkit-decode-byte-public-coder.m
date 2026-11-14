// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// A typedstream-style coder that offers only the public NSCoder primitives,
// like Apple's NSUnarchiver: no -decodeByte. Bytes read as "c" count up from 1.
@interface PublicCoder : NSCoder {
@public
    NSMutableArray *_objects;
    int _bytes, _floats;
}
@end
@implementation PublicCoder
- (BOOL)allowsKeyedCoding { return NO; }
- (NSInteger)versionForClassName:(NSString *)className { return 17; }
// NSCoder's -decodeValuesOfObjCTypes: passes the rest of its type string on each call, so only the first
// character names the value to write.
- (void)decodeValueOfObjCType:(const char *)type at:(void *)data {
    switch (type[0]) {
    case 'c':
        *(char *)data = (char)++_bytes;
        break;
    case 'f':
        *(float *)data = (_floats++ == 0) ? 7.0f : 5.0f;
        break;
    case 's':
        *(short *)data = 9;
        break;
    case '@': {
        // A decoded object comes back retained, as NSUnarchiver's does; -decodeObject autoreleases it.
        id object = [_objects objectAtIndex:0];
        *(id *)data = [object isEqual:[NSNull null]] ? nil : [object retain];
        [_objects removeObjectAtIndex:0];
        break;
    }
    default:
        expect(NO, [NSString stringWithFormat:@"the decoder asked for an unexpected type %s", type]);
    }
}
@end

int main(void) {
    @autoreleasepool {
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:1 pixelsHigh:1 bitsPerSample:8 samplesPerPixel:4
                            hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                         bytesPerRow:0 bitsPerPixel:0] autorelease];
        PublicCoder *coder = [PublicCoder new];
        coder->_objects = [[NSMutableArray alloc] initWithObjects:@"legacy", rep, [NSNull null], [NSNull null], nil];

        // Version 17 of the typedstream NSImage reads 15 flag bytes through the coder.
        NSImage *image = nil;
        @try {
            image = [[NSImage alloc] initWithCoder:coder];
        } @catch (NSException *exception) {
            expect(NO, [NSString stringWithFormat:@"a legacy NSImage decodes through the public NSCoder API: %@",
                                                  [exception reason]]);
        }
        expect(image != nil, @"the legacy NSImage was created");
        expect(coder->_bytes == 15, @"the image read 15 bytes with the \"c\" type");
        expect(NSEqualSizes([image size], NSMakeSize(7, 5)), @"the image keeps the decoded size");
        expect([[image representations] count] == 1, @"the image has its one representation");
        [image release];
        [coder->_objects release];
        [coder release];
        // The helper is inline: no image exports it, so the UIFoundation objects that decode NSFont
        // need not import it from AppKit (UIFoundation sits below AppKit and must link on its own).
        expect(dlsym(RTLD_DEFAULT, "NSAppKitDecodeByte") == NULL,
               @"NSAppKitDecodeByte is not a symbol of any image");
        NSLog(@"PASS: legacy decoders read bytes through the public NSCoder API");
    }
    return 0;
}
