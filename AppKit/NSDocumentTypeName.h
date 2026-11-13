// Private. Document type names as AppKit reports them: a CFBundleDocumentTypes entry that declares
// LSItemContentTypes is named by its uniform type identifiers, any other entry by its CFBundleTypeName
// (Document-Based App Programming Guide; NSDocumentController, NSDocument).
#import <Foundation/Foundation.h>

// Every type name of an entry; the first one is the entry's primary name.
static inline NSArray *NSDocumentTypeNamesForInfo(NSDictionary *info) {
    NSArray *contentTypes = [info objectForKey: @"LSItemContentTypes"];
    if ([contentTypes count] > 0)
        return contentTypes;
    NSString *name = [info objectForKey: @"CFBundleTypeName"];
    return name != nil ? [NSArray arrayWithObject: name] : [NSArray array];
}

static inline NSString *NSDocumentTypeNameForInfo(NSDictionary *info) {
    return [NSDocumentTypeNamesForInfo(info) firstObject];
}

// Whether type names the entry: by one of its type names or, as before the UTI names, by its CFBundleTypeName.
static inline BOOL NSDocumentInfoHasTypeName(NSDictionary *info, NSString *type) {
    if (type == nil)
        return NO;
    return [NSDocumentTypeNamesForInfo(info) containsObject: type] ||
           [type isEqualToString: [info objectForKey: @"CFBundleTypeName"]];
}
