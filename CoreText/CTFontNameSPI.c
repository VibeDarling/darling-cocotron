#include <CoreText/CoreTextExport.h>
#include <stdio.h>
#include <stdlib.h>

// A private function that Font Book imports and that no permitted source documents (neither its arguments,
// nor how its ID selects a name, nor what its languages select), so a call prints the name and aborts instead
// of answering with an invented name.
CORETEXT_EXPORT void CTFontCopyLocalizedNameByIDWithLanguages(void)
{
    fprintf(stderr, "CoreText: CTFontCopyLocalizedNameByIDWithLanguages is not implemented\n");
    abort();
}
