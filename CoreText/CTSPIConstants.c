#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CGBase.h>

// CoreText names that stock apps import and that no public header declares (Books, Font Book, App Store). The
// types come from WebKit's open-source CoreTextSPI.h (kCTFontUIFontDesign*, kCTUIFontTextStyle*,
// kCTFontDescriptorTextStyleAttribute: CFStringRef; kCTFontWidthExtraCompressed: CGFloat). For the rest the
// type is assumed to be CFStringRef (GUESS: not in the public documentation).
//
// GUESS (NEEDS-REAL-MAC): no permitted source gives the string values, so each string constant carries its own
// name. Code that compares against these same objects works; a table keyed with Apple's strings would miss.

// UI font design (trait key and the designs it takes)
const CFStringRef kCTFontUIFontDesignDefault = CFSTR("kCTFontUIFontDesignDefault");
const CFStringRef kCTFontUIFontDesignTrait = CFSTR("kCTFontUIFontDesignTrait");
const CFStringRef kCTFontUIFontDesignRounded = CFSTR("kCTFontUIFontDesignRounded");

// UI font text styles
const CFStringRef kCTUIFontTextStyleBody = CFSTR("kCTUIFontTextStyleBody");
const CFStringRef kCTUIFontTextStyleCallout = CFSTR("kCTUIFontTextStyleCallout");
const CFStringRef kCTUIFontTextStyleCaption1 = CFSTR("kCTUIFontTextStyleCaption1");
const CFStringRef kCTUIFontTextStyleCaption2 = CFSTR("kCTUIFontTextStyleCaption2");
const CFStringRef kCTUIFontTextStyleFootnote = CFSTR("kCTUIFontTextStyleFootnote");
const CFStringRef kCTUIFontTextStyleHeadline = CFSTR("kCTUIFontTextStyleHeadline");
const CFStringRef kCTUIFontTextStyleShortBody = CFSTR("kCTUIFontTextStyleShortBody");
const CFStringRef kCTUIFontTextStyleShortCaption1 = CFSTR("kCTUIFontTextStyleShortCaption1");
const CFStringRef kCTUIFontTextStyleShortFootnote = CFSTR("kCTUIFontTextStyleShortFootnote");
const CFStringRef kCTUIFontTextStyleShortHeadline = CFSTR("kCTUIFontTextStyleShortHeadline");
const CFStringRef kCTUIFontTextStyleShortSubhead = CFSTR("kCTUIFontTextStyleShortSubhead");
const CFStringRef kCTUIFontTextStyleSubhead = CFSTR("kCTUIFontTextStyleSubhead");
const CFStringRef kCTUIFontTextStyleTallBody = CFSTR("kCTUIFontTextStyleTallBody");
const CFStringRef kCTUIFontTextStyleTitle0 = CFSTR("kCTUIFontTextStyleTitle0");
const CFStringRef kCTUIFontTextStyleTitle1 = CFSTR("kCTUIFontTextStyleTitle1");
const CFStringRef kCTUIFontTextStyleTitle2 = CFSTR("kCTUIFontTextStyleTitle2");
const CFStringRef kCTUIFontTextStyleTitle3 = CFSTR("kCTUIFontTextStyleTitle3");

// Descriptor attributes, keys and options
const CFStringRef kCTFontDescriptorTextStyleAttribute = CFSTR("kCTFontDescriptorTextStyleAttribute");
const CFStringRef kCTFontDesignLanguagesAttribute = CFSTR("kCTFontDesignLanguagesAttribute");
const CFStringRef kCTFontAssetType = CFSTR("kCTFontAssetType");
const CFStringRef kCTFontAssetFontInfoKey = CFSTR("kCTFontAssetFontInfoKey");
const CFStringRef kCTFontCollectionIncludeStubFontsOption = CFSTR("kCTFontCollectionIncludeStubFontsOption");
const CFStringRef kCTFontManagerAvailableFontURLsAddedKey = CFSTR("kCTFontManagerAvailableFontURLsAddedKey");
const CFStringRef kCTFontManagerAvailableFontURLsRemovedKey = CFSTR("kCTFontManagerAvailableFontURLsRemovedKey");
const CFStringRef kCTFontValidationOptionRunDynamic = CFSTR("kCTFontValidationOptionRunDynamic");
const CFStringRef kCTFontValidationResults = CFSTR("kCTFontValidationResults");

// A font width, a CGFloat like the other kCTFontWidth values (WebKit CoreTextSPI.h).
// GUESS (NEEDS-REAL-MAC): the value; -0.8 is only a point inside the documented trait range of -1.0 to 1.0.
const CGFloat kCTFontWidthExtraCompressed = -0.8;
