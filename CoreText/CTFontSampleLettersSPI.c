#include <CoreText/CoreTextExport.h>
#include <stdio.h>
#include <stdlib.h>

// A private function that Font Book imports and that no permitted source documents (neither its arguments, nor
// what its languages select, nor the form of the result), so a call prints the name and aborts instead of
// answering with an invented sample.
CORETEXT_EXPORT void CTFontCopySampleLettersWithLanguages(void)
{
    fprintf(stderr, "CoreText: CTFontCopySampleLettersWithLanguages is not implemented\n");
    abort();
}
