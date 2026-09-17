#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreTextExport.h>
#import <CoreText/CTFontDescriptor.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef const struct __CTFontCollection* CTFontCollectionRef;
typedef struct __CTFontCollection* CTMutableFontCollectionRef;

typedef CFComparisonResult (*CTFontCollectionSortDescriptorsCallback)(CTFontDescriptorRef first, CTFontDescriptorRef second, void * _Nullable refCon);

enum {
    kCTFontCollectionCopyDefaultOptions = 0,
    kCTFontCollectionCopyUnique = 1,
    kCTFontCollectionCopyStandardSort = 2
};
typedef uint32_t CTFontCollectionCopyOptions;

CORETEXT_EXPORT const CFStringRef kCTFontCollectionRemoveDuplicatesOption;
CORETEXT_EXPORT const CFStringRef kCTFontCollectionIncludeDisabledFontsOption;
CORETEXT_EXPORT const CFStringRef kCTFontCollectionDisallowAutoActivationOption;

CORETEXT_EXPORT CFTypeID CTFontCollectionGetTypeID(void);

CORETEXT_EXPORT CTFontCollectionRef _Nullable CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef _Nullable options);
CORETEXT_EXPORT CTFontCollectionRef _Nullable CTFontCollectionCreateWithFontDescriptors(CFArrayRef _Nullable queryDescriptors, CFDictionaryRef _Nullable options);
CORETEXT_EXPORT CTFontCollectionRef _Nullable CTFontCollectionCreateCopyWithFontDescriptors(CTFontCollectionRef collection, CFArrayRef _Nullable queryDescriptors, CFDictionaryRef _Nullable options);
CORETEXT_EXPORT CTMutableFontCollectionRef _Nullable CTFontCollectionCreateMutableCopy(CTFontCollectionRef collection);

CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionRef collection);
CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptorsWithOptions(CTFontCollectionRef collection, CFDictionaryRef _Nullable options);
CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(
    CTFontCollectionRef collection,
    CTFontCollectionSortDescriptorsCallback _Nullable sortCallback,
    void * _Nullable refCon);
CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptorsForFamily(
    CTFontCollectionRef collection,
    CFStringRef familyName,
    CFDictionaryRef _Nullable options);

CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCopyQueryDescriptors(CTFontCollectionRef collection);
CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCopyExclusionDescriptors(CTFontCollectionRef collection);
CORETEXT_EXPORT void CTFontCollectionSetQueryDescriptors(CTMutableFontCollectionRef collection, CFArrayRef _Nullable descriptors);
CORETEXT_EXPORT void CTFontCollectionSetExclusionDescriptors(CTMutableFontCollectionRef collection, CFArrayRef _Nullable descriptors);

CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCopyFontAttribute(CTFontCollectionRef collection, CFStringRef attributeName, CTFontCollectionCopyOptions options);
CORETEXT_EXPORT CFArrayRef _Nullable CTFontCollectionCopyFontAttributes(CTFontCollectionRef collection, CFSetRef attributeNames, CTFontCollectionCopyOptions options);

CF_IMPLICIT_BRIDGING_DISABLED
