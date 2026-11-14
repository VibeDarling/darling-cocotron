#import <AppKit/AppKitExport.h>
#import <Foundation/NSString.h>
#import <Foundation/NSGeometry.h>

#import <AppKit/NSAccessibilityConstants.h>
#import <AppKit/NSAccessibilityProtocols.h>

@class NSView;

APPKIT_EXPORT void NSAccessibilityPostNotification(id element,
                                                   NSString *notification);

APPKIT_EXPORT NSString *NSAccessibilityRoleDescription(NSString *role,
                                                       NSString *subrole);
APPKIT_EXPORT NSString *NSAccessibilityRoleDescriptionForUIElement(id element);
APPKIT_EXPORT NSString *
NSAccessibilityActionDescription(NSAccessibilityActionName action);
APPKIT_EXPORT void NSAccessibilityRaiseBadArgumentException(id element,
                                                            NSString *attribute,
                                                            id value);

// With a view and a point in the view's coordinates, returns the point in screen coordinates.
APPKIT_EXPORT NSPoint NSAccessibilityPointInView(NSView *parentView, NSPoint point);

// Private: AppKit exports it but no public header or document declares it. A call prints its name and aborts.
APPKIT_EXPORT void NSAccessibilityUnregisterUniqueIdForUIElement(id element);

APPKIT_EXPORT id NSAccessibilityUnignoredAncestor(id element);
APPKIT_EXPORT id NSAccessibilityUnignoredDescendant(id element);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildren(NSArray *originalChildren);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildrenForOnlyChild(id originalChild);

// There is no accessibility server: objects have no attributes and overrides
// aren't kept.
@interface NSObject (NSAccessibility)
- (NSArray *) accessibilityAttributeNames;
- accessibilityAttributeValue: (NSString *) attribute;
- (BOOL) accessibilitySetOverrideValue: (id) value forAttribute: (NSString *) attribute;

@property(getter=isAccessibilityElement) BOOL accessibilityElement;
@property(copy) NSString *accessibilityLabel;
@property(copy) NSString *accessibilityHelp;
@property(copy) id accessibilityValue;
@property(copy) NSString *accessibilityTitle;
@property(copy) NSString *accessibilityIdentifier;
@end
