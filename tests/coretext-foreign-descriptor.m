// Links CoreText without AppKit. A descriptor this CoreText cannot read stops by class name instead of recursing
// through the object's own methods (the shared cache's, which call the CTFontDescriptor functions with self) or
// reading as empty. Dictionaries and objects that answer -fontAttributes, like Cocotron's NSFontDescriptor, are read.
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface ForeignDescriptor : NSObject
@end

@implementation ForeignDescriptor
- (id)objectForKey:(id)key { return [(id)CTFontDescriptorCopyAttribute((CTFontDescriptorRef)self, (CFStringRef)key) autorelease]; }
- (id)copyWithZone:(NSZone *)zone { return (id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self); }
@end

@interface DuckDescriptor : NSObject
@end

@implementation DuckDescriptor
- (NSDictionary *)fontAttributes { return @{ (id)kCTFontNameAttribute: @"Duck" }; }
@end

// Named like the cache's class: instances are never asked for their attributes, whatever they answer.
@interface NSCTFontDescriptor : NSObject
@end

@implementation NSCTFontDescriptor
- (NSDictionary *)fontAttributes { return [(id)CTFontDescriptorCopyAttributes((CTFontDescriptorRef)self) autorelease]; }
@end

// Runs the block in a child and expects SIGABRT with the class name on stderr.
static void expectStops(const char *className, void (^block)(void))
{
    int pipefd[2];
    expect(pipe(pipefd) == 0, @"pipe");
    pid_t child = fork();
    if (child == 0)
    {
        dup2(pipefd[1], 2);
        close(pipefd[0]);
        block();
        _exit(0);
    }
    close(pipefd[1]);
    char message[512] = {0};
    ssize_t count = read(pipefd[0], message, sizeof(message) - 1);
    int status = 0;
    waitpid(child, &status, 0);
    expect(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT, [NSString stringWithFormat:@"%s stops", className]);
    expect(count > 0 && strstr(message, className) != NULL, [NSString stringWithFormat:@"%s is named", className]);
}

int main(void)
{
    @autoreleasepool
    {
        ForeignDescriptor *foreign = [[ForeignDescriptor alloc] init];
        expectStops("ForeignDescriptor", ^{ CTFontDescriptorCopyAttribute((CTFontDescriptorRef)foreign, kCTFontNameAttribute); });
        expectStops("ForeignDescriptor", ^{ CTFontCreateWithFontDescriptor((CTFontDescriptorRef)foreign, 12, NULL); });

        NSCTFontDescriptor *cacheLike = [[NSCTFontDescriptor alloc] init];
        expectStops("NSCTFontDescriptor", ^{ CTFontDescriptorCopyAttributes((CTFontDescriptorRef)cacheLike); });

        DuckDescriptor *duck = [[DuckDescriptor alloc] init];
        CFTypeRef duckName = CTFontDescriptorCopyAttribute((CTFontDescriptorRef)duck, kCTFontNameAttribute);
        expect(duckName != NULL && CFEqual(duckName, CFSTR("Duck")), @"an object that answers -fontAttributes is read through it");
        CFRelease(duckName);

        CTFontDescriptorRef derived = CTFontDescriptorCreateCopyWithSymbolicTraits(
                (CTFontDescriptorRef)duck, kCTFontTraitBold, kCTFontTraitBold);
        expect(derived != NULL && CTFontDescriptorGetSymbolicTraits(derived) == kCTFontTraitBold, @"a copy made from it carries the traits");
        CFTypeRef derivedName = CTFontDescriptorCopyAttribute(derived, kCTFontNameAttribute);
        expect(derivedName != NULL && CFEqual(derivedName, CFSTR("Duck")), @"and its name");
        CFRelease(derivedName);
        CFRelease(derived);
        NSLog(@"coretext-foreign-descriptor: ok");
    }
    return 0;
}
