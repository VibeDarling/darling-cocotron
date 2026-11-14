#import <AppKit/NSSharingService.h>

NSSharingServiceName const NSSharingServiceNameAddToIPhoto = @"com.apple.share.System.add-to-iphoto";
NSSharingServiceName const NSSharingServiceNameAddToSafariReadingList = @"com.apple.share.System.add-to-safari-reading-list";
NSSharingServiceName const NSSharingServiceNameComposeEmail = @"com.apple.share.Mail.compose";
NSSharingServiceName const NSSharingServiceNameComposeMessage = @"com.apple.messages.ShareExtension";

NSSharingServiceName const NSSharingServiceNamePostOnFacebook = @"com.apple.share.Facebook.post";
NSSharingServiceName const NSSharingServiceNamePostOnTwitter = @"com.apple.share.Twitter.post";
NSSharingServiceName const NSSharingServiceNamePostOnSinaWeibo = @"com.apple.share.SinaWeibo.post";
NSSharingServiceName const NSSharingServiceNamePostOnTencentWeibo = @"com.apple.share.TencentWeibo.post";
NSSharingServiceName const NSSharingServiceNamePostOnLinkedIn = @"com.apple.share.LinkedIn.post";

// NSSharingService.h (macOS 10.12) declares this name without a value, and Apple's documentation does not give
// one. The value is the one two open-source SDK binding tables list, which also match every sibling name above:
// darwinkit generate/modules/enums/macos/appkit:2799 and hsiafan/cocoa generate/meta/AppKit/NSSharingServiceName.json:23-24
// ("com.apple.share.CloudSharing"). NEEDS-REAL-MAC to confirm. The "com.apple.share.CloudSharing.invite" string seen
// in the Safari share-menu preferences is an extension identifier, not this constant. Nothing in this tree reads it, and
// the service it names (a persistent iCloud sharing session) does not exist here.
NSSharingServiceName const NSSharingServiceNameCloudSharing = @"com.apple.share.CloudSharing";

@implementation NSSharingService

+ (NSArray<NSSharingService *> *) sharingServicesForItems: (NSArray *) items {
    return [NSArray array];
}

+ (NSSharingService *) sharingServiceNamed: (NSSharingServiceName) serviceName {
    return nil;
}

- (instancetype) initWithTitle: (NSString *) title image: (NSImage *) image alternateImage: (NSImage *) alternateImage handler: (void (^)(void)) block {
    if ((self = [super init])) {
        _title = [title copy];
        _image = [image retain];
        _alternateImage = [alternateImage retain];
    }
    return self;
}

- (void) dealloc {
    [_title release];
    [_image release];
    [_alternateImage release];
    [_menuItemTitle release];
    [super dealloc];
}

- (NSString *) title {
    return _title;
}

- (NSImage *) image {
    return _image;
}

- (NSImage *) alternateImage {
    return _alternateImage;
}

- (NSString *) menuItemTitle {
    return _menuItemTitle;
}

- (void) setMenuItemTitle: (NSString *) title {
    [_menuItemTitle release];
    _menuItemTitle = [title copy];
}

- (id <NSSharingServiceDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate: (id <NSSharingServiceDelegate>) delegate {
    _delegate = delegate;
}

- (BOOL) canPerformWithItems: (NSArray *) items {
    return NO;
}

- (void) performWithItems: (NSArray *) items {
}

@end

@implementation NSSharingServicePicker

- (instancetype) initWithItems: (NSArray *) items {
    if ((self = [super init])) {
        _items = [items retain];
    }
    return self;
}

- (void) dealloc {
    [_items release];
    [super dealloc];
}

- (id <NSSharingServicePickerDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate: (id <NSSharingServicePickerDelegate>) delegate {
    _delegate = delegate;
}

- (NSMenu *) menu {
    return [[[NSMenu alloc] initWithTitle: @"Share"] autorelease];
}

- (void) showRelativeToRect: (NSRect) rect ofView: (NSView *) view preferredEdge: (NSRectEdge) preferredEdge {
}

@end
