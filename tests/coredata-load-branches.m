#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <string.h>
#include <unistd.h>
#include <darling-boundary-diagnostics.h>

@interface AuthoredStoreError : NSAtomicStore
@end
@implementation AuthoredStoreError
- (BOOL)load:(NSError **)error {
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPersistentStoreOpenError userInfo:nil];
    return NO;
}
@end
@interface AuthoredStoreEmptyError : NSAtomicStore
@end
@implementation AuthoredStoreEmptyError
- (BOOL)load:(NSError **)error { (void)error; return NO; }
@end
@interface AuthoredStoreException : NSAtomicStore
@end
@implementation AuthoredStoreException
- (BOOL)load:(NSError **)error {
    (void)error;
    @throw [NSException exceptionWithName:@"AuthoredStoreFailure" reason:@"Expected authored exception" userInfo:nil];
}
@end
@interface AuthoredStoreSuccessError : NSAtomicStore
@end
@implementation AuthoredStoreSuccessError
- (BOOL)load:(NSError **)error {
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPersistentStoreOpenError userInfo:nil];
    return YES;
}
@end

static int checkCase(const char *selectedCase) {
    darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_FIXTURE_CASE_ENTER);
    int stage = 110;
    @autoreleasepool {
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"authored-coredata-branch-%ld", (long)getpid()]];
        NSFileManager *files = [NSFileManager defaultManager];
        if (![files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL])
            return 101;
        @try {
            stage = 111;
            [NSPersistentStoreCoordinator registerStoreClass:[AuthoredStoreError class] forStoreType:@"AuthoredPreflightStore"];
            stage = 112;
            NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] init] autorelease];
            stage = 113;
            NSEntityDescription *entity = [[[NSEntityDescription alloc] init] autorelease];
            stage = 114;
            entity.name = @"AuthoredRecord";
            stage = 115;
            entity.managedObjectClassName = @"NSManagedObject";
            stage = 116;
            entity.properties = @[];
            stage = 117;
            model.entities = @[entity];
            stage = 118;
            NSPersistentStoreDescription *description = [NSPersistentStoreDescription
                persistentStoreDescriptionWithURL:[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"store.xml"]]];
            stage = 119;
            BOOL success = NO, retainedStore = NO;
            if (!strcmp(selectedCase, "model")) {
                model = nil;
            } else if (!strcmp(selectedCase, "sqlite")) {
                if ([[NSPersistentStoreCoordinator registeredStoreTypes] objectForKey:NSSQLiteStoreType])
                    return 102;
                description.type = NSSQLiteStoreType;
            } else if (!strcmp(selectedCase, "unknown")) {
                description.type = @"AuthoredUnknownStore";
            } else if (!strcmp(selectedCase, "nonfile")) {
                description.type = @"AuthoredPreflightStore";
                description.URL = [NSURL URLWithString:@"https://example.invalid/authored"];
            } else if (!strcmp(selectedCase, "readonly")) {
                description.type = @"AuthoredPreflightStore";
                description.readOnly = YES;
            } else if (!strcmp(selectedCase, "directory")) {
                description.type = @"AuthoredPreflightStore";
                NSString *blocked = [directory stringByAppendingPathComponent:@"blocked"];
                if (![@"authored" writeToFile:blocked atomically:YES encoding:NSUTF8StringEncoding error:NULL])
                    return 103;
                description.URL = [NSURL fileURLWithPath:[blocked stringByAppendingPathComponent:@"nested/store.xml"]];
            } else if (!strcmp(selectedCase, "memory")) {
                description.type = NSInMemoryStoreType;
                success = YES;
                retainedStore = YES;
            } else {
                Class store = Nil;
                if (!strcmp(selectedCase, "coordinator-error")) store = [AuthoredStoreError class];
                if (!strcmp(selectedCase, "coordinator-empty")) store = [AuthoredStoreEmptyError class];
                if (!strcmp(selectedCase, "coordinator-exception")) store = [AuthoredStoreException class];
                if (!strcmp(selectedCase, "coordinator-success-error")) {
                    store = [AuthoredStoreSuccessError class];
                    retainedStore = YES;
                }
                if (!store)
                    return 104;
                description.type = @"AuthoredDiagnosticStore";
                [NSPersistentStoreCoordinator registerStoreClass:store forStoreType:description.type];
            }
            stage = 120;
            NSPersistentContainer *container = [[[NSPersistentContainer alloc]
                initWithName:@"AuthoredContainer" managedObjectModel:model] autorelease];
            stage = 121;
            container.persistentStoreDescriptions = @[description];
            __block NSUInteger calls = 0;
            __block BOOL resultMatches = NO;
            stage = 122;
            [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *selected, NSError *error) {
                calls++;
                resultMatches = selected == description && ((error == nil) == success);
            }];
            if (calls != 1 || !resultMatches)
                return 105;
            if ([[container.persistentStoreCoordinator persistentStores] count] != (retainedStore ? 1 : 0))
                return 106;
            darling_boundary_emit(getenv("DARLING_BOUNDARY_SOCKET"), DARLING_DIAG_FIXTURE_CASE_COMPLETE);
            return 0;
        } @catch (NSException *exception) {
            (void)exception;
            return stage;
        } @finally {
            [files removeItemAtPath:directory error:NULL];
        }
    }
}

int main(int argc, char **argv) {
    if (argc != 2)
        return 100;
    if (!strcmp(argv[1], "all")) {
        const char *cases[] = {"model", "sqlite", "unknown", "nonfile", "readonly", "directory", "memory",
            "coordinator-error", "coordinator-empty", "coordinator-exception", "coordinator-success-error"};
        for (NSUInteger index = 0; index < sizeof(cases)/sizeof(cases[0]); index++) {
            int status = checkCase(cases[index]);
            if (status)
                return status;
        }
        return 0;
    }
    return checkCase(argv[1]);
}
