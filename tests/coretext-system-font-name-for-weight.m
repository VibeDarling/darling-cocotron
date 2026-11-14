// Links CoreText without AppKit. Cache frameworks call CTFontDescriptorCopyNameForSystemFontOfWeight when an app asks for a system
// font of a weight (+[NSFont systemFontOfSize:weight:]); Cocotron used to stop the process by name at the call. The signature is a
// guess (see CTFontDescriptor.m): the name must exist and, for every weight, return a non-empty string (the value is a guess). Whether CoreText
// can open that name is not checked: CTFontCreateWithName falls back to another face (Helvetica, family Nimbus Sans here) for
// any name and never returns NULL, so such a check could not fail.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>

int main(void)
{
    @autoreleasepool
    {
        CFStringRef (*copyName)(CGFloat) = (CFStringRef (*)(CGFloat))dlsym(RTLD_DEFAULT, "CTFontDescriptorCopyNameForSystemFontOfWeight");
        if (!copyName)
        {
            NSLog(@"FAIL: CTFontDescriptorCopyNameForSystemFontOfWeight is defined");
            return 1;
        }
        CGFloat weights[] = {-1.0, -0.8, 0.0, 0.4, 0.62, 1.0};
        for (unsigned i = 0; i < sizeof(weights) / sizeof(weights[0]); i++)
        {
            CFStringRef name = copyName(weights[i]);
            if (!name || CFGetTypeID(name) != CFStringGetTypeID() || CFStringGetLength(name) == 0)
            {
                NSLog(@"FAIL: weight %g has no name", (double)weights[i]);
                return 1;
            }
            CFRelease(name);
        }
        NSLog(@"coretext-system-font-name-for-weight: ok");
    }
    return 0;
}
