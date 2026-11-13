#import <AppKit/AppKit.h>
#include <stdio.h>

#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); return 1; } } while (0)

// NSGlassEffectView (macOS 26 documentation): a view with contentView, cornerRadius, tintColor, style and
// effectIsInteractive. The content view is embedded in the glass.
int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame: NSMakeRect(0, 0, 200, 100)];
    EXPECT([glass isKindOfClass: [NSView class]], "NSGlassEffectView is an NSView");
    EXPECT([glass contentView] == nil, "no content view by default");
    EXPECT(![glass effectIsInteractive], "glass is static by default");
    EXPECT([glass style] == NSGlassEffectViewStyleRegular, "default style is regular");
    EXPECT([glass tintColor] == nil, "no tint by default");

    NSView *content = [[NSView alloc] initWithFrame: NSMakeRect(5, 5, 10, 10)];
    [glass setContentView: content];
    EXPECT([glass contentView] == content, "the content view is stored");
    EXPECT([content superview] == glass, "the content view is embedded in the glass");
    EXPECT(NSEqualRects([content frame], [glass bounds]), "the content view fills the glass");
    [glass setFrameSize: NSMakeSize(300, 150)];
    EXPECT(NSEqualRects([content frame], [glass bounds]), "the content view follows the glass when it resizes");

    NSView *other = [[NSView alloc] initWithFrame: NSZeroRect];
    [glass setContentView: other];
    EXPECT([content superview] == nil, "the old content view is removed");
    EXPECT([other superview] == glass, "the new content view is embedded");
    [glass setContentView: nil];
    EXPECT([glass contentView] == nil && [other superview] == nil, "a nil content view empties the glass");

    [glass setCornerRadius: 12.5];
    EXPECT([glass cornerRadius] == 12.5, "cornerRadius round-trips");
    [glass setStyle: NSGlassEffectViewStyleClear];
    EXPECT([glass style] == NSGlassEffectViewStyleClear, "style round-trips");
    [glass setEffectIsInteractive: YES];
    EXPECT([glass effectIsInteractive], "effectIsInteractive round-trips");

    NSColor *tint = [NSColor colorWithCalibratedRed: 1 green: 0 blue: 0 alpha: 1];
    [glass setTintColor: tint];
    EXPECT([[glass tintColor] isEqual: tint], "tintColor round-trips");
    [glass setTintColor: nil];
    EXPECT([glass tintColor] == nil, "tintColor clears");

    // A content view that was moved elsewhere is not pulled out of its new superview by replacing it.
    NSView *moved = [[NSView alloc] initWithFrame: NSZeroRect];
    NSView *newHome = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 50, 50)];
    [glass setContentView: moved];
    [newHome addSubview: moved];
    [glass setContentView: nil];
    EXPECT([moved superview] == newHome, "replacing a content view that left the glass keeps it where it is");
    [moved release];
    [newHome release];

    // A nib decodes the content view as the glass's subview.
    NSGlassEffectView *source = [[NSGlassEffectView alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)];
    NSView *decodedContent = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)];
    [source setContentView: decodedContent];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject: source];
    NSGlassEffectView *decoded = [NSKeyedUnarchiver unarchiveObjectWithData: archive];
    EXPECT([decoded isKindOfClass: [NSGlassEffectView class]], "an archived glass view decodes");
    EXPECT([[decoded subviews] count] == 1 && [decoded contentView] == [[decoded subviews] objectAtIndex: 0], "the decoded subview is the content view");
    [decodedContent release];
    [source release];

    [other release];
    [content release];
    [glass release];
    [pool drain];
    printf("PASS: NSGlassEffectView\n");
    return 0;
}
