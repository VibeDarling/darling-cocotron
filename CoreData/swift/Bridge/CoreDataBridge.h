#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSArray * _Nullable DarlingCoreDataExecuteFetch(NSManagedObjectContext *context, id request, NSError * _Nullable * _Nullable error);
// NSNotFound on error.
FOUNDATION_EXPORT NSInteger DarlingCoreDataCount(NSManagedObjectContext *context, id request, NSError * _Nullable * _Nullable error);
// An object's objectWillChange publisher, once one is made. Setting one answers the publisher the
// object keeps: another thread's, when it got there first. From then on the object calls the
// handler with it before each change it reports to key-value observing.
typedef void (*DarlingCoreDataWillChangeHandler)(id publisher);
FOUNDATION_EXPORT id _Nullable DarlingCoreDataObjectWillChangePublisher(NSManagedObject *object);
FOUNDATION_EXPORT id DarlingCoreDataSetObjectWillChangePublisher(NSManagedObject *object, id publisher, DarlingCoreDataWillChangeHandler handler);
NS_ASSUME_NONNULL_END
