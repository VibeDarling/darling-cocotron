#import <AppKit/AppKitExport.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>

NS_ASSUME_NONNULL_BEGIN

// An immutable set of named ways to make a user interface smaller. Options combine with the
// optionsBy... methods and compare with containsOptions: and intersectsOptions:.
@interface NSUserInterfaceCompressionOptions : NSObject <NSCopying, NSSecureCoding> {
    NSSet *_identifiers;
}

- (instancetype) init;
- (instancetype) initWithIdentifier: (NSString *) identifier;
- (instancetype) initWithCompressionOptions: (NSSet<NSUserInterfaceCompressionOptions *> *) options;

@property(readonly) BOOL isEmpty;

- (BOOL) containsOptions: (NSUserInterfaceCompressionOptions *) options;
- (BOOL) intersectsOptions: (NSUserInterfaceCompressionOptions *) options;
- (NSUserInterfaceCompressionOptions *) optionsByAddingOptions: (NSUserInterfaceCompressionOptions *) options;
- (NSUserInterfaceCompressionOptions *) optionsByRemovingOptions: (NSUserInterfaceCompressionOptions *) options;

@property(class, readonly) NSUserInterfaceCompressionOptions *hideImagesOption;
@property(class, readonly) NSUserInterfaceCompressionOptions *hideTextOption;
@property(class, readonly) NSUserInterfaceCompressionOptions *reduceMetricsOption;
@property(class, readonly) NSUserInterfaceCompressionOptions *breakEqualWidthsOption;
@property(class, readonly) NSUserInterfaceCompressionOptions *standardOptions;

@end

NS_ASSUME_NONNULL_END
