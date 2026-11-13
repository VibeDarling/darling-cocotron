// A font descriptor made by another CoreText must not make this one recurse. Links CoreText without AppKit.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int savedStderr = -1;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        if (savedStderr >= 0)
            dup2(savedStderr, 2);
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static int nesting;
static int messages;

// Answers like the descriptor class of the shared cache's CoreText: every accessor is implemented on top of the
// CTFontDescriptor functions, with the object itself as the descriptor. The nesting bound only keeps a recursing
// CoreText from overflowing the stack, so that it fails here instead of crashing.
@interface ForeignDescriptor : NSObject <NSCopying>
@end

@implementation ForeignDescriptor

- (id)objectForKey:(id)key
{
    messages++;
    id result = nil;
    if (++nesting <= 20)
        result = [(id)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)self, (CFStringRef)key) autorelease];
    nesting--;
    return result;
}

- (id)fontAttributes
{
    messages++;
    id result = nil;
    if (++nesting <= 20)
        result = [(id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self) autorelease];
    nesting--;
    return result;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

@end

static CTFontDescriptorRef ownDescriptor(CFStringRef name)
{
    return CTFontDescriptorCreateWithNameAndSize(name, 0);
}

int main(void)
{
    @autoreleasepool
    {
        FILE *log = tmpfile();
        expect(log != NULL, @"log file");
        int logFile = fileno(log);
        savedStderr = dup(2);
        dup2(logFile, 2);

        CTFontDescriptorRef foreign = (CTFontDescriptorRef)[[ForeignDescriptor alloc] init];

        CFTypeRef name = CTFontDescriptorCopyAttribute(foreign, kCTFontNameAttribute);
        expect(name == NULL, @"a foreign descriptor has no attributes to read");
        expect(messages == 0, @"a foreign descriptor is not asked for its attributes");

        CFDictionaryRef attributes = CTFontDescriptorCopyAttributes(foreign);
        expect(attributes != NULL && CFGetTypeID(attributes) == CFDictionaryGetTypeID() &&
               CFDictionaryGetCount(attributes) == 0, @"its attributes are an empty dictionary");
        CFRelease(attributes);
        expect(CTFontDescriptorGetSymbolicTraits(foreign) == 0, @"no symbolic traits");

        CTFontDescriptorRef traited = CTFontDescriptorCreateCopyWithSymbolicTraits(
            foreign, kCTFontTraitMonoSpace, kCTFontTraitMonoSpace);
        expect(traited != NULL && CTFontDescriptorGetSymbolicTraits(traited) == kCTFontTraitMonoSpace,
               @"a symbolic trait can be added to a foreign descriptor");
        CFRelease(traited);

        CTFontDescriptorRef changed = CTFontDescriptorCreateCopyWithAttributes(
            foreign, (CFDictionaryRef)[NSDictionary dictionaryWithObject:@"Example"
                                                                  forKey:(id)kCTFontNameAttribute]);
        CFTypeRef changedName = CTFontDescriptorCopyAttribute(changed, kCTFontNameAttribute);
        expect(changedName != NULL && [(id)changedName isEqual:@"Example"],
               @"attributes added to a foreign descriptor are kept");
        CFRelease(changedName);
        CFRelease(changed);

        int type = 6, selector = 1, tag = 0x77676874;
        CFNumberRef typeNumber = CFNumberCreate(NULL, kCFNumberIntType, &type);
        CFNumberRef selectorNumber = CFNumberCreate(NULL, kCFNumberIntType, &selector);
        CFNumberRef tagNumber = CFNumberCreate(NULL, kCFNumberIntType, &tag);
        CTFontDescriptorRef featured = CTFontDescriptorCreateCopyWithFeature(foreign, typeNumber, selectorNumber);
        CFArrayRef settings = CTFontDescriptorCopyAttribute(featured, kCTFontFeatureSettingsAttribute);
        expect(settings != NULL && CFArrayGetCount(settings) == 1, @"a feature can be added to a foreign descriptor");
        CTFontDescriptorRef varied = CTFontDescriptorCreateCopyWithVariation(foreign, tagNumber, 0.5);
        CFDictionaryRef variation = CTFontDescriptorCopyAttribute(varied, kCTFontVariationAttribute);
        expect(variation != NULL && CFDictionaryGetCount(variation) == 1,
               @"a variation can be added to a foreign descriptor");
        CFRelease(variation);
        CFRelease(varied);
        CFRelease(settings);
        CFRelease(featured);
        CFRelease(tagNumber);
        CFRelease(selectorNumber);
        CFRelease(typeNumber);

        CTFontRef baseline = CTFontCreateWithName(CFSTR("Helvetica"), 14, NULL);
        expect(baseline != NULL, @"a font is available by name");
        CTFontRef font = CTFontCreateWithFontDescriptor(foreign, 14, NULL);
        expect(font != NULL, @"a font is made from a foreign descriptor");
        {
            expect(CTFontGetSize(font) == 14, @"size");
            CTFontRef copy = CTFontCreateCopyWithAttributes(font, 0, NULL, foreign);
            expect(copy != NULL && CTFontGetSize(copy) == 14, @"a font copy takes a foreign descriptor");
            CFRelease(copy);
            CGFontRef graphicsFont = CTFontCopyGraphicsFont(font, NULL);
            CTFontRef wrapped = CTFontCreateWithGraphicsFont(graphicsFont, 11, NULL, foreign);
            expect(wrapped != NULL && CTFontGetSize(wrapped) == 11, @"a graphics font takes a foreign descriptor");
            CFRelease(wrapped);
            CGFontRelease(graphicsFont);
            CFRelease(font);
        }
        CFRelease(baseline);

        CTFontRef unnamed = CTFontCreateWithFontDescriptor(NULL, 13, NULL);
        expect(unnamed != NULL && CTFontGetSize(unnamed) == 13, @"a NULL descriptor still makes a font");
        CFRelease(unnamed);
        expect(messages == 0, @"no foreign descriptor was asked for anything");

        CTFontDescriptorRef ours = ownDescriptor(CFSTR("Example"));
        CFTypeRef ownName = CTFontDescriptorCopyAttribute(ours, kCTFontNameAttribute);
        expect(ownName != NULL && [(id)ownName isEqual:@"Example"], @"CoreText's own descriptor keeps its name");
        CFRelease(ownName);
        CFDictionaryRef ownAttributes = CTFontDescriptorCopyAttributes(ours);
        expect(CFDictionaryGetCount(ownAttributes) == 1, @"and answers its attributes");
        CFRelease(ownAttributes);
        CFRelease(ours);

        dup2(savedStderr, 2);
        close(savedStderr);
        savedStderr = -1;
        lseek(logFile, 0, SEEK_SET);
        NSMutableData *logged = [NSMutableData data];
        char buffer[512];
        ssize_t count;
        while ((count = read(logFile, buffer, sizeof buffer)) > 0)
            [logged appendBytes:buffer length:(NSUInteger)count];
        fclose(log);
        // NSLog is assumed to write to stderr, as Cocotron's and Darling's Foundation do.
        NSString *text = [[[NSString alloc] initWithData:logged encoding:NSUTF8StringEncoding] autorelease];
        NSArray *lines = [text componentsSeparatedByString:@"ForeignDescriptor"];
        expect(lines.count == 2, @"the foreign class is reported once, by name");
        expect([text rangeOfString:@"(null)"].location == NSNotFound, @"a NULL descriptor is not reported");

        [(id)foreign release];
        puts("PASS");
    }
    return 0;
}
