#include <CoreGraphics/CoreGraphicsExport.h>
#include <stdio.h>
#include <stdlib.h>

// Private window-server functions that guest applications import. Nothing public documents their
// arguments or results, so a call prints the name and aborts instead of answering with an invented value.
#define CGS_FAIL_LOUD(name) \
    COREGRAPHICS_EXPORT void name(void) { \
        fprintf(stderr, "CoreGraphics: " #name " is not implemented\n"); \
        abort(); \
    }

CGS_FAIL_LOUD(CGSEventIsAppUnresponsive)
CGS_FAIL_LOUD(CGSSessionCopyCurrentSessionProperties)
