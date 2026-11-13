#import <AppKit/NSUserInterfaceCompression.h>

static NSString *const NSUserInterfaceCompressionIdentifiersKey = @"NSIdentifiers";

@interface NSUserInterfaceCompressionOptions ()
- (instancetype) _initWithIdentifiers: (NSSet *) identifiers;
- (NSSet *) _identifiers;
@end

// A nil option set behaves as the empty set.
static NSSet *identifiersOf(NSUserInterfaceCompressionOptions *options) {
    return [options _identifiers] ?: [NSSet set];
}

@implementation NSUserInterfaceCompressionOptions

+ (BOOL) supportsSecureCoding {
    return YES;
}

+ (NSUserInterfaceCompressionOptions *) _optionNamed: (NSString *) identifier {
    return [[[self alloc] initWithIdentifier: identifier] autorelease];
}

// The identifiers are internal; only their identity matters to callers.
+ (NSUserInterfaceCompressionOptions *) hideImagesOption {
    static NSUserInterfaceCompressionOptions *option;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ option = [[self _optionNamed: @"NSUserInterfaceCompressionHideImages"] retain]; });
    return option;
}

+ (NSUserInterfaceCompressionOptions *) hideTextOption {
    static NSUserInterfaceCompressionOptions *option;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ option = [[self _optionNamed: @"NSUserInterfaceCompressionHideText"] retain]; });
    return option;
}

+ (NSUserInterfaceCompressionOptions *) reduceMetricsOption {
    static NSUserInterfaceCompressionOptions *option;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ option = [[self _optionNamed: @"NSUserInterfaceCompressionReduceMetrics"] retain]; });
    return option;
}

+ (NSUserInterfaceCompressionOptions *) breakEqualWidthsOption {
    static NSUserInterfaceCompressionOptions *option;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ option = [[self _optionNamed: @"NSUserInterfaceCompressionBreakEqualWidths"] retain]; });
    return option;
}

// GUESS: the documentation calls these "standard" options without listing them; all four are used.
+ (NSUserInterfaceCompressionOptions *) standardOptions {
    static NSUserInterfaceCompressionOptions *options;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        options = [[[[[self hideImagesOption] optionsByAddingOptions: [self hideTextOption]]
            optionsByAddingOptions: [self reduceMetricsOption]]
            optionsByAddingOptions: [self breakEqualWidthsOption]] retain];
    });
    return options;
}

- (instancetype) _initWithIdentifiers: (NSSet *) identifiers {
    if ((self = [super init]) != nil) {
        _identifiers = [identifiers copy];
    }
    return self;
}

- (instancetype) init {
    return [self _initWithIdentifiers: [NSSet set]];
}

- (instancetype) initWithIdentifier: (NSString *) identifier {
    if (identifier == nil) {
        [self release];
        [NSException raise: NSInvalidArgumentException format: @"-[NSUserInterfaceCompressionOptions initWithIdentifier:] needs an identifier"];
    }
    return [self _initWithIdentifiers: [NSSet setWithObject: identifier]];
}

- (instancetype) initWithCompressionOptions: (NSSet *) options {
    NSMutableSet *identifiers = [NSMutableSet set];
    for (NSUserInterfaceCompressionOptions *option in options) {
        [identifiers unionSet: identifiersOf(option)];
    }
    return [self _initWithIdentifiers: identifiers];
}

- (NSSet *) _identifiers {
    return _identifiers;
}

- (void) dealloc {
    [_identifiers release];
    [super dealloc];
}

- (BOOL) isEmpty {
    return [_identifiers count] == 0;
}

- (BOOL) containsOptions: (NSUserInterfaceCompressionOptions *) options {
    return [identifiersOf(options) isSubsetOfSet: _identifiers];
}

- (BOOL) intersectsOptions: (NSUserInterfaceCompressionOptions *) options {
    return [_identifiers intersectsSet: identifiersOf(options)];
}

- (NSUserInterfaceCompressionOptions *) optionsByAddingOptions: (NSUserInterfaceCompressionOptions *) options {
    NSMutableSet *identifiers = [_identifiers mutableCopy];
    [identifiers unionSet: identifiersOf(options)];
    NSUserInterfaceCompressionOptions *result = [[[self class] alloc] _initWithIdentifiers: identifiers];
    [identifiers release];
    return [result autorelease];
}

- (NSUserInterfaceCompressionOptions *) optionsByRemovingOptions: (NSUserInterfaceCompressionOptions *) options {
    NSMutableSet *identifiers = [_identifiers mutableCopy];
    [identifiers minusSet: identifiersOf(options)];
    NSUserInterfaceCompressionOptions *result = [[[self class] alloc] _initWithIdentifiers: identifiers];
    [identifiers release];
    return [result autorelease];
}

- (BOOL) isEqual: (id) other {
    if (![other isKindOfClass: [NSUserInterfaceCompressionOptions class]]) {
        return NO;
    }
    return [_identifiers isEqualToSet: identifiersOf(other)];
}

- (NSUInteger) hash {
    return [_identifiers hash];
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (void) encodeWithCoder: (NSCoder *) coder {
    [coder encodeObject: [_identifiers allObjects] forKey: NSUserInterfaceCompressionIdentifiersKey];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    NSArray *identifiers = [coder decodeObjectOfClasses: [NSSet setWithObjects: [NSArray class], [NSString class], nil]
                                                 forKey: NSUserInterfaceCompressionIdentifiersKey];
    return [self _initWithIdentifiers: [NSSet setWithArray: identifiers ?: @[]]];
}

@end
