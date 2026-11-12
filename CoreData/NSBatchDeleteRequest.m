#import <CoreData/NSBatchDeleteRequest.h>
#import <CoreData/NSManagedObjectContext.h>
#import <CoreData/NSFetchRequest.h>
#import "NSBatchDeleteRequest-Private.h"

@implementation NSPersistentStoreRequest

@synthesize affectedStores = _affectedStores;

- (NSPersistentStoreRequestType)requestType {
    return 0;
}

- (id)copyWithZone:(NSZone *)zone {
    NSPersistentStoreRequest *copy = NSCopyObject(self, 0, zone);
    copy->_affectedStores = [_affectedStores retain];
    return copy;
}

- (void)dealloc {
    [_affectedStores release];
    [super dealloc];
}

@end

@implementation NSPersistentStoreResult
@end

@implementation NSBatchDeleteRequest

@synthesize resultType = _resultType;

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetch {
    self = [super init];
    if (self) _fetchRequest = [fetch copy];
    return self;
}

- (instancetype)initWithObjectIDs:(NSArray *)objects {
    self = [super init];
    if (self) _objectIDs = [objects copy];
    return self;
}

- (NSPersistentStoreRequestType)requestType {
    return NSBatchDeleteRequestType;
}

- (NSFetchRequest *)fetchRequest {
    return [[_fetchRequest copy] autorelease];
}

- (NSArray *)_objectIDs {
    return _objectIDs;
}

- (id)copyWithZone:(NSZone *)zone {
    NSBatchDeleteRequest *copy = [super copyWithZone:zone];
    copy->_fetchRequest = [_fetchRequest copy];
    copy->_objectIDs = [_objectIDs copy];
    return copy;
}

- (void)dealloc {
    [_fetchRequest release];
    [_objectIDs release];
    [super dealloc];
}

@end

@implementation NSBatchDeleteResult

@synthesize result = _result;
@synthesize resultType = _resultType;

- (instancetype)_initWithResult:(id)result type:(NSBatchDeleteRequestResultType)type {
    self = [super init];
    if (self) {
        _result = [result retain];
        _resultType = type;
    }
    return self;
}

- (void)dealloc {
    [_result release];
    [super dealloc];
}

@end
