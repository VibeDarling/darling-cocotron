/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import "NSCustomResource.h"
#import <AppKit/NSImage.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSString.h>

// SF Symbol names are lowercase words joined by periods, such as "gearshape.fill". Anything else
// in an image resource, say "AMSMIDIWindowIcon", is an app image and must stay a missing image.
static BOOL isSystemSymbolName(NSString *name) {
    if ([name length] == 0)
        return NO;
    for (NSUInteger i = 0; i < [name length]; i++) {
        unichar c = [name characterAtIndex: i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.'))
            return NO;
    }
    return YES;
}

@implementation NSCustomResource

- initWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        NSKeyedUnarchiver *keyed = (NSKeyedUnarchiver *) coder;

        _className = [[keyed decodeObjectForKey: @"NSClassName"] retain];
        _resourceName = [[keyed decodeObjectForKey: @"NSResourceName"] retain];
    } else {
        [coder decodeValuesOfObjCTypes:"@@", &_className, &_resourceName];
    }

    return self;
}

- (void) dealloc {
    [_className release];
    [_resourceName release];
    [super dealloc];
}

- awakeAfterUsingCoder: (NSCoder *) coder {
    if ([_className isEqualToString: @"NSImage"]) {
        NSImage *image = [NSImage imageNamed: _resourceName];

        // A nib names an SF Symbol the same way it names an image.
        if (image == nil && isSystemSymbolName(_resourceName))
            image = [NSImage imageWithSystemSymbolName: _resourceName
                              accessibilityDescription: nil];

        if ([_resourceName hasSuffix: @"Template"])
            [image setTemplate: YES];

        if (image != nil) {
            [self release];
            return [image retain];
        }
    }

    NSLog(@"Could not find image named '%@'", _resourceName);

    return [[NSImage alloc] init];
}

@end
