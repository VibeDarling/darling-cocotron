#import <AppKit/AppKitExport.h>
#include <stdio.h>
#include <stdlib.h>

// A private AppKit function that UIKit-for-Mac clients import. Nothing public documents its meaning or its
// arguments, so it fails loudly instead of answering with an invented width factor.
APPKIT_EXPORT void _NSLocalizedUserInterfaceWidthFactor(void) {
    fprintf(stderr, "AppKit: _NSLocalizedUserInterfaceWidthFactor is not implemented\n");
    abort();
}
