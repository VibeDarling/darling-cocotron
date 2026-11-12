#import <CoreData/NSPersistentStoreRequest.h>

@class NSFetchRequest;

typedef NS_ENUM(NSUInteger, NSBatchDeleteRequestResultType) {
    NSBatchDeleteResultTypeStatusOnly = 0,
    NSBatchDeleteResultTypeObjectIDs = 1,
    NSBatchDeleteResultTypeCount = 2
};

// Deletes the objects a fetch request matches straight from the stores, without the delete
// rules or the calling context's pending changes.
@interface NSBatchDeleteRequest : NSPersistentStoreRequest {
    NSFetchRequest *_fetchRequest;
    NSArray *_objectIDs;
    NSBatchDeleteRequestResultType _resultType;
}

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetch;
- (instancetype)initWithObjectIDs:(NSArray *)objects;
@property NSBatchDeleteRequestResultType resultType;
@property(readonly, copy) NSFetchRequest *fetchRequest;

@end

@interface NSBatchDeleteResult : NSPersistentStoreResult {
    id _result;
    NSBatchDeleteRequestResultType _resultType;
}

@property(readonly, retain) id result;
@property(readonly) NSBatchDeleteRequestResultType resultType;

@end
