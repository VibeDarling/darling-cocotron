#include <CoreGraphics/CoreGraphicsExport.h>
#include <stdio.h>
#include <stdlib.h>

// A private function that ColorSync Utility imports and that no permitted source documents (neither its
// arguments nor what its "alpha" selects), so a call prints the name and aborts instead of making a bitmap
// context from a guessed signature.
COREGRAPHICS_EXPORT void CGBitmapContextCreateWithAlpha(void)
{
    fprintf(stderr, "CoreGraphics: CGBitmapContextCreateWithAlpha is not implemented\n");
    abort();
}
