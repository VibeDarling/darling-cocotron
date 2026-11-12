#import "CoreDataBridge.h"
#import <objc/runtime.h>
#import <stdatomic.h>

NSArray *DarlingCoreDataExecuteFetch(NSManagedObjectContext *context, id request, NSError **error) {
    return [context executeFetchRequest:(NSFetchRequest *)request error:error];
}

NSInteger DarlingCoreDataCount(NSManagedObjectContext *context, id request, NSError **error) {
    return (NSInteger)[context countForFetchRequest:(NSFetchRequest *)request error:error];
}

static char PublisherKey;
static _Atomic(DarlingCoreDataWillChangeHandler) WillChangeHandler;

id DarlingCoreDataObjectWillChangePublisher(NSManagedObject *object) {
    return objc_getAssociatedObject(object, &PublisherKey);
}

id DarlingCoreDataSetObjectWillChangePublisher(NSManagedObject *object, id publisher, DarlingCoreDataWillChangeHandler handler) {
    atomic_store(&WillChangeHandler, handler);
    @synchronized (object) {
        id existing = objc_getAssociatedObject(object, &PublisherKey);
        if (existing) return existing;
        objc_setAssociatedObject(object, &PublisherKey, publisher, OBJC_ASSOCIATION_RETAIN);
        return publisher;
    }
}

static void SendWillChange(NSManagedObject *object) {
    DarlingCoreDataWillChangeHandler handler = atomic_load(&WillChangeHandler);
    if (!handler) return;
    id publisher = objc_getAssociatedObject(object, &PublisherKey);
    if (publisher) handler(publisher);
}

// NSManagedObject leaves these to NSObject, so a category can stand in front of them.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation NSManagedObject (DarlingObjectWillChange)

- (void)willChangeValueForKey:(NSString *)key {
    SendWillChange(self);
    [super willChangeValueForKey:key];
}

- (void)willChange:(NSKeyValueChange)change valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key {
    SendWillChange(self);
    [super willChange:change valuesAtIndexes:indexes forKey:key];
}

- (void)willChangeValueForKey:(NSString *)key withSetMutation:(NSKeyValueSetMutationKind)mutation usingObjects:(NSSet *)objects {
    SendWillChange(self);
    [super willChangeValueForKey:key withSetMutation:mutation usingObjects:objects];
}

@end
#pragma clang diagnostic pop
