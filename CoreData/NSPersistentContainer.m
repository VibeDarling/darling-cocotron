#include <darling-boundary-diagnostics.h>
#import <CoreData/NSPersistentContainer.h>
#import <CoreData/NSPersistentStoreDescription.h>
#import <CoreData/NSPersistentStoreCoordinator.h>
#import <CoreData/NSManagedObjectContext.h>
#import <CoreData/NSManagedObjectModel.h>
#import <CoreData/CoreDataErrors.h>
#import <dispatch/dispatch.h>

static NSError *ContainerError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code
                          userInfo:@{NSLocalizedDescriptionKey:message}];
}

@implementation NSPersistentContainer

@synthesize name = _name;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize viewContext = _viewContext;
@synthesize persistentStoreDescriptions = _persistentStoreDescriptions;

+ (NSURL *)defaultDirectoryURL {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                  inDomains:NSUserDomainMask] firstObject];
}

- (instancetype)initWithName:(NSString *)name {
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_MODEL_LOAD_ENTER);
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *modelURL = [bundle URLForResource:name withExtension:@"mom"];
    if (!modelURL) {
        NSURL *directory = [bundle URLForResource:name withExtension:@"momd"];
        NSArray *contents = directory ? [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:directory includingPropertiesForKeys:nil options:0 error:NULL] : nil;
        NSMutableArray *models = [NSMutableArray array];
        for (NSURL *URL in contents)
            if ([[URL pathExtension] isEqual:@"mom"])
                [models addObject:URL];
        if ([models count] == 1)
            modelURL = [models objectAtIndex:0];
    }
    NSManagedObjectModel *model = nil;
    if (modelURL) {
        @try {
            model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
            if (![model isKindOfClass:[NSManagedObjectModel class]]) {
                [model release];
                model = nil;
            }
        } @catch (NSException *exception) {
            model = nil;
        }
    }
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), model ? DARLING_DIAG_MODEL_LOAD_OK : DARLING_DIAG_MODEL_LOAD_ERROR);
    self = [self initWithName:name managedObjectModel:model];
    [model release];
    return self;
}

- (instancetype)initWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model {
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_CONTAINER_INIT_ENTER);
    self = [super init];
    if (self) {
        _name = [name copy];
        _managedObjectModel = [model retain];
        if (!model)
            _modelError = [ContainerError(NSPersistentStoreIncompatibleSchemaError,
                                         @"The managed object model could not be loaded.") retain];
        else
            _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                initWithManagedObjectModel:model];
        _viewContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_viewContext setPersistentStoreCoordinator:_persistentStoreCoordinator];
        NSURL *URL = [[[self class] defaultDirectoryURL]
            URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"sqlite"]];
        NSPersistentStoreDescription *description = [[NSPersistentStoreDescription alloc] initWithURL:URL];
        _persistentStoreDescriptions = [[NSArray alloc] initWithObjects:description, nil];
        [description release];
        darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), model ? DARLING_DIAG_CONTAINER_INIT_OK : DARLING_DIAG_CONTAINER_INIT_MODEL_ERROR);
    }
    return self;
}

- (void)loadDescription:(NSPersistentStoreDescription *)description
            completion:(void (^)(NSPersistentStoreDescription *, NSError *))block {
    NSError *error = _modelError;
    const char *endpoint = getenv("DARLING_BOUNDARY_SOCKET");
    if (error)
        darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_MODEL_ERROR);
    if (!error && ![[NSPersistentStoreCoordinator registeredStoreTypes] objectForKey:description.type]) {
        darling_boundary_emit(endpoint, [description.type isEqual:NSSQLiteStoreType] ?
            DARLING_DIAG_CONTAINER_LOAD_UNSUPPORTED_SQLITE : DARLING_DIAG_CONTAINER_LOAD_UNSUPPORTED_TYPE);
        error = ContainerError(NSPersistentStoreInvalidTypeError, @"The requested persistent store type is unsupported.");
    }
    if (!error && ![description.type isEqual:NSInMemoryStoreType]) {
        if (![description.URL isFileURL]) {
            darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_NONFILE_URL);
            error = ContainerError(NSPersistentStoreOpenError, @"A file URL is required for this persistent store.");
        } else if (description.isReadOnly && ![[NSFileManager defaultManager] fileExistsAtPath:[description.URL path]]) {
            darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_READONLY_MISSING);
            error = ContainerError(NSPersistentStoreOpenError, @"The read-only persistent store does not exist.");
        } else if (!description.isReadOnly) {
            BOOL created = [[NSFileManager defaultManager]
                createDirectoryAtURL:[description.URL URLByDeletingLastPathComponent]
                withIntermediateDirectories:YES attributes:nil error:&error];
            if (!created) {
                darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_DIRECTORY_ERROR);
                if (!error)
                    error = ContainerError(NSPersistentStoreOpenError, @"The persistent store directory could not be created.");
            }
        }
    }
    if (!error) {
        NSMutableDictionary *options = [[description.options mutableCopy] autorelease];
        [_persistentStoreCoordinator lock];
        @try {
            darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_COORDINATOR_ENTER);
            NSPersistentStore *store = [_persistentStoreCoordinator addPersistentStoreWithType:description.type
                    configuration:description.configuration URL:description.URL options:options error:&error];
            if (!store) {
                darling_boundary_emit(endpoint, error ? DARLING_DIAG_CONTAINER_LOAD_COORDINATOR_ERROR :
                    DARLING_DIAG_CONTAINER_LOAD_COORDINATOR_EMPTY_ERROR);
                if (!error)
                    error = ContainerError(NSPersistentStoreOpenError, @"The persistent store could not be opened.");
            }
        } @catch (NSException *exception) {
            darling_boundary_emit(endpoint, DARLING_DIAG_CONTAINER_LOAD_COORDINATOR_EXCEPTION);
            error = ContainerError(NSPersistentStoreOpenError, @"The persistent store could not be opened.");
        } @finally {
            [_persistentStoreCoordinator unlock];
        }
    }
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), error ? DARLING_DIAG_CONTAINER_LOAD_ERROR : DARLING_DIAG_CONTAINER_LOAD_SUCCESS);
    block(description, error);
}

- (void)loadPersistentStoresWithCompletionHandler:(void (^)(NSPersistentStoreDescription *, NSError *))block {
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_CONTAINER_LOAD_ENTER);
    if (!block)
        [NSException raise:NSInvalidArgumentException format:@"A persistent store completion handler is required"];
    for (NSPersistentStoreDescription *description in [[_persistentStoreDescriptions copy] autorelease]) {
        if (description.shouldAddStoreAsynchronously)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    [self loadDescription:description completion:block];
                }
            });
        else
            [self loadDescription:description completion:block];
    }
}

- (NSManagedObjectContext *)newBackgroundContext {
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc]
        initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:_persistentStoreCoordinator];
    return context;
}

- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *))block {
    NSManagedObjectContext *context = [self newBackgroundContext];
    [context performBlock:^{ block(context); }];
    [context release];
}

- (void)dealloc {
    [_name release];
    [_managedObjectModel release];
    [_persistentStoreCoordinator release];
    [_viewContext release];
    [_persistentStoreDescriptions release];
    [_modelError release];
    [super dealloc];
}

@end
