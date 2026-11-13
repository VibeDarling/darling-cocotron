// Link with candidate AppKit; no windows are needed.
#import <AppKit/AppKit.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

// NSUserInterfaceCompressionOptions (AppKit, macOS 10.13): immutable option sets that combine and compare.
int main(void) {
    @autoreleasepool {
        NSUserInterfaceCompressionOptions *images = NSUserInterfaceCompressionOptions.hideImagesOption;
        NSUserInterfaceCompressionOptions *text = NSUserInterfaceCompressionOptions.hideTextOption;
        NSUserInterfaceCompressionOptions *metrics = NSUserInterfaceCompressionOptions.reduceMetricsOption;
        NSUserInterfaceCompressionOptions *widths = NSUserInterfaceCompressionOptions.breakEqualWidthsOption;

        expect([[NSUserInterfaceCompressionOptions alloc] init].isEmpty, @"init makes an empty set");
        expect(!images.isEmpty, @"a named option is not empty");
        expect(![images isEqual:text] && ![metrics isEqual:widths], @"the four named options are distinct");
        expect(images == NSUserInterfaceCompressionOptions.hideImagesOption, @"a named option is a shared instance");

        NSUserInterfaceCompressionOptions *both = [images optionsByAddingOptions:text];
        expect([both containsOptions:images] && [both containsOptions:text], @"a union contains its parts");
        expect(![images containsOptions:both], @"a part does not contain the union");
        expect([both intersectsOptions:images], @"a union intersects a part");
        expect(![images intersectsOptions:text], @"distinct options do not intersect");

        NSUserInterfaceCompressionOptions *back = [both optionsByRemovingOptions:text];
        expect([back isEqual:images], @"removing a part leaves the other");
        expect([[both optionsByRemovingOptions:both] isEmpty], @"removing everything is empty");
        expect([both containsOptions:[[NSUserInterfaceCompressionOptions alloc] init]], @"every set contains the empty set");

        NSSet *parts = [NSSet setWithObjects:images, text, nil];
        expect([[[NSUserInterfaceCompressionOptions alloc] initWithCompressionOptions:parts] isEqual:both], @"initWithCompressionOptions: unions the set");
        NSUserInterfaceCompressionOptions *custom = [[NSUserInterfaceCompressionOptions alloc] initWithIdentifier:@"com.example.custom"];
        expect(![custom intersectsOptions:both] && [custom isEqual:[[NSUserInterfaceCompressionOptions alloc] initWithIdentifier:@"com.example.custom"]], @"identifiers define equality");

        NSUserInterfaceCompressionOptions *standard = NSUserInterfaceCompressionOptions.standardOptions;
        expect([standard containsOptions:images] && [standard containsOptions:text] && [standard containsOptions:metrics] && [standard containsOptions:widths], @"standard options include the named ones");

        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:both requiringSecureCoding:YES error:NULL];
        NSUserInterfaceCompressionOptions *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSUserInterfaceCompressionOptions class] fromData:data error:NULL];
        expect([decoded isEqual:both], @"secure coding round-trips");
        NSLog(@"PASS: NSUserInterfaceCompressionOptions");
    }
    return 0;
}
