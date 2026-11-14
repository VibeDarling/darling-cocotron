#include <CoreText/CoreTextExport.h>
#include <stdio.h>
#include <stdlib.h>

// Private functions that Font Book imports and that no permitted source documents (neither their arguments nor
// what they answer), so a call prints the name and aborts instead of answering with an invented value. The
// prototypes are unknown on purpose: nothing returns. Replace an entry with the implementation when a source
// documents the function (a duplicate definition fails the link).
static void failLoud(const char *name)
{
    fprintf(stderr, "CoreText: %s is not implemented\n", name);
    abort();
}

#define FAIL_LOUD(name) CORETEXT_EXPORT void name(void) { failLoud(#name); }

FAIL_LOUD(CTFontCopyStringForGlyph)
FAIL_LOUD(CTFontDescriptorCopyDownloadableFontAttributesForRequests)
FAIL_LOUD(CTFontDescriptorCopyName)
FAIL_LOUD(CTFontDescriptorIsVisible)
FAIL_LOUD(CTFontGetDefaultAscent)
FAIL_LOUD(CTFontManagerCompareFontDescriptors2)
FAIL_LOUD(CTFontManagerValidateFonts)
