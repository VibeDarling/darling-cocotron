#import <AppKit/NSUserInterfaceItemIdentification.h>

@implementation NSObject (NSUserInterfaceItemIdentification)

- (NSUserInterfaceItemIdentifier) userInterfaceItemIdentifier {
    if ([self respondsToSelector: @selector(identifier)]) {
        return [self identifier];
    }
    return nil;
}


// Spotlight UI search registration. Cocotron has no such search service, so
// the identifier is retained only to keep the caller's registration balanced.
- (void) registerUserInterfaceItemSearch: (id) search {
}

- (void) unregisterUserInterfaceItemSearch: (id) search {
}

- (void) setUserInterfaceItemIdentifier: (NSUserInterfaceItemIdentifier) userInterfaceItemIdentifier {
    if ([self respondsToSelector: @selector(setIdentifier:)]) {
        [self setIdentifier: userInterfaceItemIdentifier];
    }
}

@end
