/* Copyright (c) 2006-2007 Christopher J. W. Lloyd <cjwl@objc.net>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSRaise.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSRunningApplication.h>
#import <Foundation/Foundation.h>

NSString *const NSWorkspaceApplicationKey = @"NSWorkspaceApplicationKey";

NSString *const NSWorkspaceWillPowerOffNotification =
        @"NSWorkspaceWillPowerOffNotification";

NSString *const NSWorkspaceRecycleOperation = @"NSWorkspaceRecycleOperation";
NSString *const NSWorkspaceDuplicateOperation = @"NSWorkspaceDuplicateOperation";

NSString *const NSWorkspaceLaunchConfigurationAppleEvent =
        @"NSWorkspaceLaunchConfigurationAppleEvent";
NSString *const NSWorkspaceLaunchConfigurationArguments =
        @"NSWorkspaceLaunchConfigurationArguments";
NSString *const NSWorkspaceLaunchConfigurationEnvironment =
        @"NSWorkspaceLaunchConfigurationEnvironment";
NSString *const NSWorkspaceLaunchConfigurationArchitecture =
        @"NSWorkspaceLaunchConfigurationArchitecture";

NSString *const NSWorkspaceActiveSpaceDidChangeNotification =
        @"NSWorkspaceActiveSpaceDidChangeNotification";
const NSNotificationName NSWorkspaceDidDeactivateApplicationNotification =
        @"NSWorkspaceDidDeactivateApplicationNotification";
const NSNotificationName NSWorkspaceDidWakeNotification = 
        @"NSWorkspaceDidWakeNotification";
NSString *const NSWorkspaceDidLaunchApplicationNotification =
        @"NSWorkspaceDidLaunchApplicationNotification";
NSString *const NSWorkspaceDidTerminateApplicationNotification =
        @"NSWorkspaceDidTerminateApplicationNotification";
const NSNotificationName NSWorkspaceScreensDidSleepNotification =
        @"NSWorkspaceScreensDidSleepNotification";
const NSNotificationName NSWorkspaceScreensDidWakeNotification =
        @"NSWorkspaceScreensDidWakeNotification";
const NSNotificationName NSWorkspaceWillSleepNotification =
        @"NSWorkspaceWillSleepNotification";
const NSNotificationName NSWorkspaceSessionDidBecomeActiveNotification =
        @"NSWorkspaceSessionDidBecomeActiveNotification";
const NSNotificationName NSWorkspaceSessionDidResignActiveNotification =
        @"NSWorkspaceSessionDidResignActiveNotification";
NSNotificationName const NSWorkspaceDidActivateApplicationNotification = @"NSWorkspaceDidActivateApplicationNotification";

const NSNotificationName
        NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification =
                @"NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification";

NSNotificationName NSWorkspaceDidMountNotification = @"NSWorkspaceDidMountNotification";
NSNotificationName NSWorkspaceDidUnmountNotification = @"NSWorkspaceDidUnmountNotification";
NSNotificationName NSWorkspaceWillUnmountNotification = @"NSWorkspaceWillUnmountNotification";

@implementation NSWorkspace

+ (NSWorkspace *) sharedWorkspace {
    return NSThreadSharedInstance(@"NSWorkspace");
}

- init {
    _notificationCenter = [[NSNotificationCenter alloc] init];
    return self;
}

- (NSNotificationCenter *) notificationCenter {
    return _notificationCenter;
}

// Darling has no bridge to the host's accessibility display preferences yet.
// Report the standard, unmodified display mode until that bridge exists.
- (BOOL) accessibilityDisplayShouldDifferentiateWithoutColor { return NO; }
- (BOOL) accessibilityDisplayShouldIncreaseContrast { return NO; }
- (BOOL) accessibilityDisplayShouldReduceTransparency { return NO; }
- (BOOL) accessibilityDisplayShouldInvertColors { return NO; }
- (BOOL) accessibilityDisplayShouldReduceMotion { return NO; }

- (NSImage *) iconForFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSImage *) iconForFiles: (NSArray *) array {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSImage *) iconForFileType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) localizedDescriptionForType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) filenameExtension: (NSString *) extension
            isValidForType: (NSString *) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) preferredFilenameExtensionForType: (NSString *) type {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) type: (NSString *) type conformsToType: (NSString *) conformsToType {
    if (type == nil || conformsToType == nil)
        return NO;
    if ([type isEqualToString: conformsToType])
        return YES;

    // Check application document types declared in mainBundle Info.plist
    NSArray *docTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleDocumentTypes"];
    for (NSDictionary *dict in docTypes) {
        NSString *name = [dict objectForKey: @"CFBundleTypeName"];
        NSArray *contentTypes = [dict objectForKey: @"LSItemContentTypes"];
        if ([name isEqualToString: type]) {
            for (NSString *ct in contentTypes) {
                if ([ct isEqualToString: conformsToType])
                    return YES;
            }
        }
        if ([name isEqualToString: conformsToType]) {
            for (NSString *ct in contentTypes) {
                if ([ct isEqualToString: type])
                    return YES;
            }
        }
    }

    // Standard Apple pasteboard type to UTI mappings
    if (([type isEqualToString: @"NSRTFPboardType"] || [type isEqualToString: @"NeXT Rich Text Format v1.0 pasteboard type"]) &&
        [conformsToType isEqualToString: @"public.rtf"])
        return YES;
    if ([type isEqualToString: @"public.rtf"] &&
        ([conformsToType isEqualToString: @"NSRTFPboardType"] || [conformsToType isEqualToString: @"NeXT Rich Text Format v1.0 pasteboard type"]))
        return YES;

    if (([type isEqualToString: @"NSRTFDPboardType"] || [type isEqualToString: @"NeXT RTFD pasteboard type"]) &&
        [conformsToType isEqualToString: @"com.apple.rtfd"])
        return YES;
    if ([type isEqualToString: @"com.apple.rtfd"] &&
        ([conformsToType isEqualToString: @"NSRTFDPboardType"] || [conformsToType isEqualToString: @"NeXT RTFD pasteboard type"]))
        return YES;

    if (([type isEqualToString: @"NSStringPboardType"] || [type isEqualToString: @"NSString"]) &&
        ([conformsToType isEqualToString: @"public.plain-text"] || [conformsToType isEqualToString: @"public.text"]))
        return YES;
    if (([type isEqualToString: @"public.plain-text"] || [type isEqualToString: @"public.utf8-plain-text"]) &&
        ([conformsToType isEqualToString: @"NSStringPboardType"] || [conformsToType isEqualToString: @"public.text"]))
        return YES;

    if ([type isEqualToString: @"NSHTMLPboardType"] && [conformsToType isEqualToString: @"public.html"])
        return YES;
    if ([type isEqualToString: @"public.html"] && [conformsToType isEqualToString: @"NSHTMLPboardType"])
        return YES;

    Class utTypeClass = NSClassFromString(@"UTType");
    if (utTypeClass != nil && [utTypeClass respondsToSelector: @selector(typeWithIdentifier:)]) {
        id t1 = [utTypeClass typeWithIdentifier: type];
        id t2 = [utTypeClass typeWithIdentifier: conformsToType];
        if (t1 != nil && t2 != nil && [t1 respondsToSelector: @selector(conformsToType:)]) {
            if ([t1 conformsToType: t2])
                return YES;
        }
    }

    return NO;
}

- (NSString *) typeOfFile: (NSString *) path error: (NSError **) error {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path withApplication: (NSString *) application {
    NSString *fullApp = [self fullPathForApplication: application];
    if (!fullApp) fullApp = application;
    NSBundle *bundle = [NSBundle bundleWithPath: fullApp];
    NSString *execPath = [bundle executablePath];
    if (!execPath) execPath = fullApp;
    NSArray *args = path ? @[path] : @[];
    @try {
        NSTask *task = [NSTask launchedTaskWithLaunchPath: execPath arguments: args];
        return task != nil;
    } @catch (id ex) {
        NSLog(@"NSWorkspace openFile:withApplication: failed: %@", ex);
        return NO;
    }
}

- (BOOL) openTempFile: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path
        fromImage: (NSImage *) image
               at: (NSPoint) point
           inView: (NSView *) view
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openFile: (NSString *) path
        withApplication: (NSString *) application
          andDeactivate: (BOOL) deactivate
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) openURL: (NSURL *) url {
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) openURL: (NSURL *) url
        configuration: (NSWorkspaceOpenConfiguration *) configuration
    completionHandler: (void (^)(NSRunningApplication *app, NSError *error)) completionHandler
{
    NSInvalidAbstractInvocation();
}

- (BOOL) selectFile: (NSString *) path
        inFileViewerRootedAtPath: (NSString *) rootedAtPath
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) slideImage: (NSImage *) image from: (NSPoint) from to: (NSPoint) to {
    NSInvalidAbstractInvocation();
}

- (BOOL) performFileOperation: (NSString *) operation
                       source: (NSString *) source
                  destination: (NSString *) destination
                        files: (NSArray *) files
                          tag: (NSInteger *) tag
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) getFileSystemInfoForPath: (NSString *) path
                      isRemovable: (BOOL *) isRemovable
                       isWritable: (BOOL *) isWritable
                    isUnmountable: (BOOL *) isUnmountable
                      description: (NSString **) description
                             type: (NSString **) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) getInfoForFile: (NSString *) path
            application: (NSString **) application
                   type: (NSString **) type
{
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) checkForRemovableMedia {
    NSInvalidAbstractInvocation();
}

- (NSArray *) mountNewRemovableMedia {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) mountedRemovableMedia {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) mountedLocalVolumePaths {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) unmountAndEjectDeviceAtPath: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) fileSystemChanged {
    NSInvalidAbstractInvocation();
    return 0;
}

- (BOOL) userDefaultsChanged {
    NSInvalidAbstractInvocation();
    return 0;
}

- (void) noteFileSystemChanged {
    NSInvalidAbstractInvocation();
}

- (void) noteFileSystemChanged: (NSString *) path {
    NSInvalidAbstractInvocation();
}

- (void) noteUserDefaultsChanged {
    NSInvalidAbstractInvocation();
}

- (BOOL) isFilePackageAtPath: (NSString *) path {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) absolutePathForAppBundleWithIdentifier: (NSString *) identifier {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSString *) pathForApplication: (NSString *) application {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) launchedApplications {
    NSInvalidAbstractInvocation();
    return 0;
}

- (NSArray *) runningApplications {
    // NSInvalidAbstractInvocation();
    return @[];
}

- (NSRunningApplication *) frontmostApplication {
    return [NSRunningApplication currentApplication];
}

- (BOOL) launchApplication: (NSString *) application {
    return [self openFile: nil withApplication: application];
}

- (BOOL) launchApplication: (NSString *) application
                  showIcon: (BOOL) showIcon
                autolaunch: (BOOL) autolaunch
{
    return [self openFile: nil withApplication: application];
}

- (void) findApplications {
}

- (NSDictionary *) activeApplication {
    return nil;
}

- (void) hideOtherApplications {
}

- (NSInteger) extendPowerOffBy: (NSInteger) milliseconds {
    return 0;
}

- (NSString *) fullPathForApplication: (NSString *) appName {
    if (!appName || [appName length] == 0)
        return nil;
    if ([appName hasSuffix: @".app"] && [[NSFileManager defaultManager] fileExistsAtPath: appName])
        return appName;
    NSString *candidate = [NSString stringWithFormat: @"/Applications/%@.app", appName];
    if ([[NSFileManager defaultManager] fileExistsAtPath: candidate])
        return candidate;
    candidate = [NSString stringWithFormat: @"/Applications/%@", appName];
    if ([[NSFileManager defaultManager] fileExistsAtPath: candidate])
        return candidate;
    return nil;
}

@end

@implementation NSWorkspace (CocotronAdditions)

- (BOOL) isFileHiddenAtPath: (NSString *) path {
    return NO;
}

@end

static dispatch_once_t _initOnceNsWorkspaceOpenConfig;
static NSWorkspaceOpenConfiguration* _singletonNsWorkspaceOpenConfig;

@implementation NSWorkspaceOpenConfiguration
+ (instancetype)configuration {
    dispatch_once(&_initOnceNsWorkspaceOpenConfig, ^{
        _singletonNsWorkspaceOpenConfig = [[NSWorkspaceOpenConfiguration alloc] init];
    });
    return _singletonNsWorkspaceOpenConfig;
}

@end

@implementation NSWorkspace (NSOpenURLsWithApplication)

// Opens file URLs with the application (by path) and other URLs with
// -openURL:. Returns nil with an error if anything couldn't be opened. Launched
// applications aren't tracked, so success returns an NSRunningApplication that
// doesn't describe the opened application.
- (NSRunningApplication *) openURLs: (NSArray<NSURL *> *) urls
               withApplicationAtURL: (NSURL *) applicationURL
                            options: (NSUInteger) options
                      configuration: (NSDictionary *) configuration
                              error: (NSError **) error
{
    BOOL ok = YES;
    for (NSURL *url in urls) {
        @try {
            if ([url isFileURL])
                ok = [self openFile: [url path] withApplication: [applicationURL path]] && ok;
            else
                ok = [self openURL: url] && ok;
        } @catch (NSException *exception) {
            ok = NO;
        }
    }
    if (!ok) {
        if (error)
            *error = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadUnknownError userInfo: nil];
        return nil;
    }
    if (error)
        *error = nil;
    return [[[NSRunningApplication alloc] init] autorelease];
}

// A nil bundle identifier opens each URL with -openURL: (the default
// bindings); otherwise the application must be found, and the URLs are opened
// as by -openURLs:withApplicationAtURL:. Launch options and the descriptor are
// ignored, and launchIdentifiers is documented as unused.
- (BOOL) openURLs: (NSArray<NSURL *> *) urls
        withAppBundleIdentifier: (NSString *) bundleIdentifier
                        options: (NSUInteger) options
 additionalEventParamDescriptor: (NSAppleEventDescriptor *) descriptor
              launchIdentifiers: (NSArray **) identifiers
{
    if (identifiers)
        *identifiers = nil;
    if (bundleIdentifier) {
        NSURL *applicationURL = [self URLForApplicationWithBundleIdentifier: bundleIdentifier];
        if (!applicationURL)
            return NO;
        return [self openURLs: urls
                 withApplicationAtURL: applicationURL
                              options: options
                        configuration: nil
                                error: NULL] != nil;
    }
    BOOL ok = YES;
    for (NSURL *url in urls) {
        @try {
            ok = [self openURL: url] && ok;
        } @catch (NSException *exception) {
            ok = NO;
        }
    }
    return ok;
}

- (NSRunningApplication *) launchApplicationAtURL: (NSURL *) url
                                          options: (NSUInteger) options
                                    configuration: (NSDictionary *) configuration
                                            error: (NSError **) error
{
    BOOL ok = NO;
    NSString *reason = nil;
    if (![url isFileURL]) {
        reason = [NSString stringWithFormat: @"%@ is not a file URL", url];
    } else {
        @try {
            ok = [self launchApplication: [url path]];
        } @catch (NSException *exception) {
            reason = [exception reason];
        }
    }
    if (!ok) {
        if (error) {
            NSDictionary *userInfo = reason
                    ? [NSDictionary dictionaryWithObject: reason forKey: NSLocalizedDescriptionKey]
                    : nil;
            *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                         code: NSFileReadUnknownError
                                     userInfo: userInfo];
        }
        return nil;
    }
    if (error)
        *error = nil;
    return [[[NSRunningApplication alloc] init] autorelease];
}

@end
