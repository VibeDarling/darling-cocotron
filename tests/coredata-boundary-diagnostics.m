#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface NSObject (AuthoredDiagnosticSelector)
- (void)authoredUnknownSelector;
@end

int main(void) {
    @autoreleasepool {
        NSPersistentStoreDescription *description = [[NSPersistentStoreDescription alloc] initWithURL:[NSURL fileURLWithPath:@"/authored-unused-store"]];
        if (!description || description.shouldAddStoreAsynchronously)
            return 76;
        NSPersistentContainer *container = [[NSPersistentContainer alloc] initWithName:@"AuthoredMissingModel"];
        __block NSUInteger calls = 0;
        __block BOOL failed = NO;
        [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *store, NSError *error) {
            calls++;
            failed = error != nil && store != nil;
        }];
        if (calls != 1 || !failed)
            return 77;
        NSObject *object = [[NSObject alloc] init];
        BOOL knownRejected = NO, unknownRejected = NO;
        @try { [object performSelector:@selector(initWithContext:) withObject:nil]; }
        @catch (NSException *exception) { knownRejected = YES; }
        @try { [object performSelector:@selector(authoredUnknownSelector)]; }
        @catch (NSException *exception) { unknownRejected = YES; }
        [object release];
        [container release];
        [description release];
        return knownRejected && unknownRejected ? 0 : 78;
    }
}
