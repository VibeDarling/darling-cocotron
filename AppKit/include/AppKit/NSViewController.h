#import <AppKit/NSResponder.h>
#import <AppKit/NSUserInterfaceItemIdentification.h>

@class NSView;

@interface NSViewController : NSResponder <NSUserInterfaceItemIdentification> {
    NSString *_nibName;
    NSBundle *_nibBundle;
    id _representedObject;
    NSString *_title;
    NSView *_view;
    NSUserInterfaceItemIdentifier _identifier;
    NSSize _preferredContentSize;
}

- initWithNibName: (NSString *) name bundle: (NSBundle *) bundle;

- (NSString *) nibName;
- (NSBundle *) nibBundle;

@property (retain) NSView *view;
// Stored for the controller's presenter; NSZeroSize until set.
@property NSSize preferredContentSize;
- (NSString *) title;
- representedObject;

- (void) setRepresentedObject: object;

- (void) setTitle: (NSString *) value;


- (void) loadView;

- (void) discardEditing;

- (BOOL) commitEditing;
- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo;

@end
