#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, NSPersistentStoreRequestType) {
    NSFetchRequestType = 1,
    NSSaveRequestType,
    NSBatchInsertRequestType = 5,
    NSBatchUpdateRequestType,
    NSBatchDeleteRequestType
};

// The base of the requests NSManagedObjectContext's -executeRequest:error: takes.
@interface NSPersistentStoreRequest : NSObject <NSCopying> {
    NSArray *_affectedStores;
}

@property(retain) NSArray *affectedStores;
@property(readonly) NSPersistentStoreRequestType requestType;

@end

@interface NSPersistentStoreResult : NSObject
@end
