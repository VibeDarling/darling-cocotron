#include <CoreGraphics/CoreGraphicsExport.h>
#include <stdio.h>

// Private window-server function that QuickTime Player imports; Cocotron declares no prototype for it.
// GUESS: no permitted source gives its arguments or result. By its name it puts windows on spaces
// (virtual desktops), and Cocotron has no spaces: every window already is on the one space there is, on the
// Wayland and X11 backends alike. So the call is a no-op that never reads its arguments, which stays correct
// whatever the real prototype is. It returns 0 (success in the CGError convention of the sibling CGS
// functions) in case the caller checks a result; a caller that ignores one is unaffected.
// The first call prints the name to stderr (once per process) so that the call is never silent.
COREGRAPHICS_EXPORT int CGSAddWindowsToSpaces(void)
{
    static int reported;
    if (!__atomic_exchange_n(&reported, 1, __ATOMIC_RELAXED)) {
        fprintf(stderr, "CoreGraphics: CGSAddWindowsToSpaces is a no-op: there are no spaces\n");
    }
    return 0;
}
