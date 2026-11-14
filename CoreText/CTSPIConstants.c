#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CGBase.h>

// CoreText names that stock apps import and that no public header declares (Books, Font Book, App Store).
// Types and values: observed on a real Mac (rung 4, macOS 26.1, our own probe symbols_d_probe1: each name found with
// dlsym, printed as a CFString), the line of the probe output is in each comment. The type of the CGFloat comes
// from WebKit's open-source CoreTextSPI.h and is confirmed by the probe.

// UI font design (trait key and the designs it takes)
const CFStringRef kCTFontUIFontDesignDefault = CFSTR("NSCTFontUIFontDesignDefault"); // probe1:4
const CFStringRef kCTFontUIFontDesignTrait = CFSTR("NSCTFontUIFontDesignTrait"); // probe1:3
const CFStringRef kCTFontUIFontDesignRounded = CFSTR("NSCTFontUIFontDesignRounded"); // probe1:6

// UI font text styles
const CFStringRef kCTUIFontTextStyleBody = CFSTR("UICTFontTextStyleBody"); // probe1:8
const CFStringRef kCTUIFontTextStyleCallout = CFSTR("UICTFontTextStyleCallout"); // probe1:9
const CFStringRef kCTUIFontTextStyleCaption1 = CFSTR("UICTFontTextStyleCaption1"); // probe1:10
const CFStringRef kCTUIFontTextStyleCaption2 = CFSTR("UICTFontTextStyleCaption2"); // probe1:11
const CFStringRef kCTUIFontTextStyleFootnote = CFSTR("UICTFontTextStyleFootnote"); // probe1:12
const CFStringRef kCTUIFontTextStyleHeadline = CFSTR("UICTFontTextStyleHeadline"); // probe1:13
const CFStringRef kCTUIFontTextStyleShortBody = CFSTR("UICTFontTextStyleShortBody"); // probe1:14
const CFStringRef kCTUIFontTextStyleShortCaption1 = CFSTR("UICTFontTextStyleShortCaption1"); // probe1:15
const CFStringRef kCTUIFontTextStyleShortFootnote = CFSTR("UICTFontTextStyleShortFootnote"); // probe1:16
const CFStringRef kCTUIFontTextStyleShortHeadline = CFSTR("UICTFontTextStyleShortHeadline"); // probe1:17
const CFStringRef kCTUIFontTextStyleShortSubhead = CFSTR("UICTFontTextStyleShortSubhead"); // probe1:18
const CFStringRef kCTUIFontTextStyleSubhead = CFSTR("UICTFontTextStyleSubhead"); // probe1:19
const CFStringRef kCTUIFontTextStyleTallBody = CFSTR("UICTFontTextStyleTallBody"); // probe1:20
const CFStringRef kCTUIFontTextStyleTitle0 = CFSTR("UICTFontTextStyleTitle0"); // probe1:21
const CFStringRef kCTUIFontTextStyleTitle1 = CFSTR("UICTFontTextStyleTitle1"); // probe1:22
const CFStringRef kCTUIFontTextStyleTitle2 = CFSTR("UICTFontTextStyleTitle2"); // probe1:23
const CFStringRef kCTUIFontTextStyleTitle3 = CFSTR("UICTFontTextStyleTitle3"); // probe1:24

// Descriptor attributes, keys and options
const CFStringRef kCTFontDescriptorTextStyleAttribute = CFSTR("NSCTFontUIUsageAttribute"); // probe1:26
const CFStringRef kCTFontDesignLanguagesAttribute = CFSTR("NSCTFontDesignLanguagesAttribute"); // probe1:41
const CFStringRef kCTFontAssetType = CFSTR("com.apple.MobileAsset.Font8"); // probe1:45
const CFStringRef kCTFontAssetFontInfoKey = CFSTR("FontInfo4"); // probe1:46
const CFStringRef kCTFontCollectionIncludeStubFontsOption = CFSTR("NSCTFontCollectionIncludeStubFontsOption"); // probe1:47
const CFStringRef kCTFontManagerAvailableFontURLsAddedKey = CFSTR("CTFontManagerAvailableFontURLsAdded"); // probe1:48
const CFStringRef kCTFontManagerAvailableFontURLsRemovedKey = CFSTR("CTFontManagerAvailableFontURLsRemoved"); // probe1:49
const CFStringRef kCTFontValidationOptionRunDynamic = CFSTR("dynamic"); // probe1:50
const CFStringRef kCTFontValidationResults = CFSTR("results"); // probe1:51

// A font width, a CGFloat like the other kCTFontWidth values (WebKit CoreTextSPI.h).
const CGFloat kCTFontWidthExtraCompressed = -0.4; // probe1:54 (-0.40000000000000002)
