// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
/* Runs the real NSWorkspace (NSOpenURLsWithApplication) category of AppKit/NSWorkspace.m against a mock NSWorkspace.
 *
 * tests/workspace-open-urls-host.sh extracts the category from NSWorkspace.m. The mock records what the category
 * asks the workspace to do (-openURL:, -openFile:withApplication:, -URLForApplicationWithBundleIdentifier:).
 * Apple documents -openURLs:withAppBundleIdentifier:options:additionalEventParamDescriptor:launchIdentifiers: as
 * opening the URLs with the app named by the bundle identifier, or with the default bindings for nil, returning
 * YES if the app was found and launched, and launchIdentifiers as unused. Electron's shell.openExternal calls it
 * with a nil bundle identifier. */
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned long NSUInteger;
typedef long NSInteger;
enum { NSFileReadUnknownError = 256 };

__attribute__((objc_root_class))
@interface NSObject {
    Class isa;
}
+ (id)alloc;
- (id)init;
- (id)autorelease;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (id)autorelease { return self; }
@end

__attribute__((objc_root_class))
@interface NSConstantString {
    Class isa;
    const char *bytes;
    unsigned int length;
}
@end
@implementation NSConstantString @end

@interface NSString : NSObject {
@public
    const char *text;
}
+ (id)stringWithFormat:(id)format, ...;
@end
@implementation NSString
+ (id)stringWithFormat:(id)format, ... { (void)format; return [[self alloc] init]; }
@end
static NSString *string(const char *text)
{
    NSString *s = [[NSString alloc] init];
    s->text = text;
    return s;
}

@interface NSURL : NSObject {
@public
    const char *text;
    int file;
}
- (int)isFileURL;
- (NSString *)path;
@end
@implementation NSURL
- (int)isFileURL { return file; }
- (NSString *)path { return file ? string(text) : nil; }
@end
static NSURL *url(const char *text, int file)
{
    NSURL *u = [[NSURL alloc] init];
    u->text = text;
    u->file = file;
    return u;
}

typedef struct {
    unsigned long state;
    id *itemsPtr;
    unsigned long *mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;

@interface NSArray<ObjectType> : NSObject {
@public
    id items[8];
    unsigned long count;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len;
@end
@implementation NSArray
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len
{
    (void)buffer; (void)len;
    if (state->state) return 0;
    state->state = 1;
    state->itemsPtr = items;
    state->mutationsPtr = &count;
    return count;
}
@end
static NSArray *array(NSURL *a, NSURL *b)
{
    NSArray *list = [[NSArray alloc] init];
    if (a) list->items[list->count++] = a;
    if (b) list->items[list->count++] = b;
    return list;
}

@interface NSDictionary : NSObject
+ (id)dictionaryWithObject:(id)object forKey:(id)key;
@end
@implementation NSDictionary
+ (id)dictionaryWithObject:(id)object forKey:(id)key { (void)object; (void)key; return [[self alloc] init]; }
@end
@interface NSError : NSObject
+ (id)errorWithDomain:(id)domain code:(NSInteger)code userInfo:(id)userInfo;
@end
@implementation NSError
+ (id)errorWithDomain:(id)domain code:(NSInteger)code userInfo:(id)userInfo
{
    (void)domain; (void)code; (void)userInfo;
    return [[self alloc] init];
}
@end
@interface NSException : NSObject
- (NSString *)reason;
@end
@implementation NSException
- (NSString *)reason { return nil; }
@end
@interface NSRunningApplication : NSObject @end
@implementation NSRunningApplication @end
@interface NSAppleEventDescriptor : NSObject @end
@implementation NSAppleEventDescriptor @end
static NSString *NSCocoaErrorDomain, *NSLocalizedDescriptionKey;

// What the category asked for, in order: "u:<url>" for -openURL:, "f:<path>@<app>" for -openFile:withApplication:.
static char calls[512];
static const char *failURL, *raiseURL;

@interface NSWorkspace : NSObject
- (BOOL)openURL:(NSURL *)u;
- (BOOL)openFile:(NSString *)path withApplication:(NSString *)application;
- (BOOL)launchApplication:(NSString *)application;
- (NSURL *)URLForApplicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end
@implementation NSWorkspace
- (BOOL)openURL:(NSURL *)u
{
    snprintf(calls + strlen(calls), sizeof calls - strlen(calls), "u:%s ", u->text);
    if (raiseURL && strcmp(u->text, raiseURL) == 0) @throw [[NSException alloc] init];
    return !(failURL && strcmp(u->text, failURL) == 0);
}
- (BOOL)openFile:(NSString *)path withApplication:(NSString *)application
{
    snprintf(calls + strlen(calls), sizeof calls - strlen(calls), "f:%s@%s ", path->text,
             application ? application->text : "nil");
    return YES;
}
- (BOOL)launchApplication:(NSString *)application { (void)application; return NO; }
- (NSURL *)URLForApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
{
    return strcmp(bundleIdentifier->text, "com.example.Viewer") == 0 ? url("/Applications/Viewer.app", 1) : nil;
}
@end

#include CATEGORY_INC

@interface NSWorkspace (Probe)
- (BOOL)openURLs:(NSArray *)urls
        withAppBundleIdentifier:(NSString *)bundleIdentifier
                        options:(NSUInteger)options
 additionalEventParamDescriptor:(NSAppleEventDescriptor *)descriptor
              launchIdentifiers:(NSArray **)identifiers;
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static BOOL openWith(NSArray *urls, const char *bundleIdentifier, NSArray **identifiers)
{
    calls[0] = 0;
    return [[[NSWorkspace alloc] init] openURLs:urls
                        withAppBundleIdentifier:bundleIdentifier ? string(bundleIdentifier) : nil
                                        options:0
                 additionalEventParamDescriptor:nil
                              launchIdentifiers:identifiers];
}

int main(void)
{
    SEL selector = @selector(openURLs:withAppBundleIdentifier:options:additionalEventParamDescriptor:launchIdentifiers:);
    if (!class_getInstanceMethod(objc_getClass("NSWorkspace"), selector)) {
        CK(0, "NSWorkspace implements %s", sel_getName(selector));
        printf("FAIL: %d checks, %d failed\n", checks, fails);
        return 1;
    }
    NSURL *web = url("https://example.com/", 0), *mail = url("mailto:a@example.com", 0);
    NSURL *file = url("/tmp/readme.txt", 1);
    NSArray *sentinel = [[NSArray alloc] init], *identifiers = sentinel;

    CK(openWith(array(web, mail), NULL, &identifiers) == YES, "nil bundle identifier: opens and returns YES");
    CK(strcmp(calls, "u:https://example.com/ u:mailto:a@example.com ") == 0,
       "nil bundle identifier: each URL goes to -openURL: in order (got \"%s\")", calls);
    CK(identifiers == nil, "launchIdentifiers is set to nil");

    failURL = "https://example.com/";
    CK(openWith(array(web, mail), NULL, NULL) == NO, "a URL that cannot be opened makes it return NO");
    CK(strcmp(calls, "u:https://example.com/ u:mailto:a@example.com ") == 0,
       "the URLs after a failure are still opened (got \"%s\")", calls);
    failURL = NULL;

    raiseURL = "https://example.com/";
    CK(openWith(array(web, mail), NULL, NULL) == NO, "an exception from -openURL: makes it return NO, not raise");
    CK(strcmp(calls, "u:https://example.com/ u:mailto:a@example.com ") == 0,
       "the URLs after an exception are still opened (got \"%s\")", calls);
    raiseURL = NULL;

    CK(openWith(array(file, web), "com.example.Viewer", NULL) == YES, "known bundle identifier: returns YES");
    CK(strcmp(calls, "f:/tmp/readme.txt@/Applications/Viewer.app u:https://example.com/ ") == 0,
       "known bundle identifier: files open with that application (got \"%s\")", calls);

    identifiers = sentinel;
    CK(openWith(array(file, web), "com.example.Missing", &identifiers) == NO, "unknown bundle identifier: NO");
    CK(calls[0] == 0, "unknown bundle identifier: nothing is opened (got \"%s\")", calls);
    CK(identifiers == nil, "launchIdentifiers is set to nil on failure too");

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
