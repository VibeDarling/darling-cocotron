// Links AppKit. An app may cast Cocotron's NSFontDescriptor to a CTFontDescriptorRef, as the two were toll-free
// before descriptors had a CF type of their own: CoreText must still read its attributes.
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#include <stdlib.h>

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
        NSFontDescriptor *descriptor = [NSFontDescriptor fontDescriptorWithName:@"DejaVu Sans" size:14];
        CTFontDescriptorRef cast = (CTFontDescriptorRef)descriptor;
        CFTypeRef name = CTFontDescriptorCopyAttribute(cast, kCTFontNameAttribute);
        expect(name != NULL && CFEqual(name, CFSTR("DejaVu Sans")), @"the name is read through the cast");
        CFRelease(name);
        CTFontRef font = CTFontCreateWithFontDescriptor(cast, 0, NULL);
        expect(font != NULL && CTFontGetSize(font) == 14, @"the size is read through the cast");
        CTFontRef direct = CTFontCreateWithName(CFSTR("DejaVu Sans"), 14, NULL);
        CFStringRef castFace = CTFontCopyPostScriptName(font), directFace = CTFontCopyPostScriptName(direct);
        expect(castFace != NULL && directFace != NULL && CFEqual(castFace, directFace), @"the font is the named face");
        CFRelease(castFace);
        CFRelease(directFace);
        CFRelease(direct);
        CFRelease(font);
        NSLog(@"coretext-nsfontdescriptor-cast: ok");
    }
    return 0;
}
