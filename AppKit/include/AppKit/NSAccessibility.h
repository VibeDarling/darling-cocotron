#import <AppKit/AppKitExport.h>
#import <Foundation/NSString.h>

#import <AppKit/NSAccessibilityConstants.h>
#import <AppKit/NSAccessibilityProtocols.h>

APPKIT_EXPORT void NSAccessibilityPostNotification(id element,
                                                   NSString *notification);

APPKIT_EXPORT NSString *NSAccessibilityRoleDescription(NSString *role,
                                                       NSString *subrole);
APPKIT_EXPORT NSString *NSAccessibilityRoleDescriptionForUIElement(id element);
APPKIT_EXPORT void NSAccessibilityRaiseBadArgumentException(id element,
                                                            NSString *attribute,
                                                            id value);

APPKIT_EXPORT id NSAccessibilityUnignoredAncestor(id element);
APPKIT_EXPORT id NSAccessibilityUnignoredDescendant(id element);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildren(NSArray *originalChildren);
APPKIT_EXPORT NSArray *NSAccessibilityUnignoredChildrenForOnlyChild(id originalChild);

@interface NSObject (NSAccessibility)
- (NSArray *) accessibilityAttributeNames;
- accessibilityAttributeValue: (NSString *) attribute;
@end
