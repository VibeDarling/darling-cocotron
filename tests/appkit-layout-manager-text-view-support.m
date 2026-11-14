// The NSTextViewSupport methods of NSLayoutManager (firstTextView, textViewForBeginningOfSelection,
// layoutManagerOwnsFirstResponderInWindow:, rulerMarkersForTextView:paragraphStyle:ruler: and
// rulerAccessoryViewForTextView:paragraphStyle:ruler:enabled:) are implemented by AppKit, as macOS declares them in AppKit's
// category, so they exist whichever UIFoundation serves NSLayoutManager.
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *imageOf(SEL selector)
{
    IMP imp = class_getMethodImplementation([NSLayoutManager class], selector);
    Dl_info info;
    expect(dladdr((void *)imp, &info) != 0 && info.dli_fname != NULL, [NSString stringWithFormat:@"%@ has an implementation", NSStringFromSelector(selector)]);
    return [NSString stringWithUTF8String:info.dli_fname];
}

int main(void)
{
    @autoreleasepool
    {
        SEL selectors[] = {@selector(firstTextView), @selector(textViewForBeginningOfSelection),
                           @selector(layoutManagerOwnsFirstResponderInWindow:),
                           @selector(rulerMarkersForTextView:paragraphStyle:ruler:),
                           @selector(rulerAccessoryViewForTextView:paragraphStyle:ruler:enabled:)};
        for (int i = 0; i < 5; i++)
        {
            NSString *image = imageOf(selectors[i]);
            expect([image containsString:@"AppKit.framework"],
                   [NSString stringWithFormat:@"%@ is implemented by AppKit (image %@)", NSStringFromSelector(selectors[i]), image]);
        }

        NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        NSLayoutManager *manager = [view layoutManager];
        expect([manager firstTextView] == view, @"firstTextView is the text view of the first container");
        expect([manager textViewForBeginningOfSelection] == view, @"textViewForBeginningOfSelection is the first text view");
        NSLayoutManager *bare = [[NSLayoutManager alloc] init];
        expect([bare firstTextView] == nil && [bare textViewForBeginningOfSelection] == nil, @"a layout manager without a container has no text view");

        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
        [[window contentView] addSubview:view];
        expect([window makeFirstResponder:view], @"the text view becomes first responder");
        expect([manager layoutManagerOwnsFirstResponderInWindow:window], @"the layout manager owns the first responder");
        expect(![bare layoutManagerOwnsFirstResponderInWindow:window], @"another layout manager does not");

        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        NSTextTab *left = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:40];
        NSTextTab *right = [[NSTextTab alloc] initWithType:NSRightTabStopType location:80];
        [style setTabStops:@[ left, right ]];
        NSRulerView *ruler = [[NSRulerView alloc] initWithScrollView:nil orientation:NSHorizontalRuler];
        NSArray *markers = [manager rulerMarkersForTextView:view paragraphStyle:style ruler:ruler];
        expect([markers count] == 2, [NSString stringWithFormat:@"one ruler marker per tab stop, got %lu", (unsigned long)[markers count]]);
        expect([[markers objectAtIndex:0] representedObject] == left && [[markers objectAtIndex:1] representedObject] == right,
               @"each marker represents its tab");
        expect([[markers objectAtIndex:0] isRemovable], @"tab markers are removable");
        expect([manager rulerAccessoryViewForTextView:view paragraphStyle:style ruler:ruler enabled:YES] == nil, @"no accessory view");
    }
    NSLog(@"appkit-layout-manager-text-view-support: all checks passed");
    return 0;
}
