/*
 This file is part of Darling.

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>

#import <CoreGraphics/CGContext.h>
#import <Onyx2D/O2Context.h>
#import <Onyx2D/O2GraphicsState.h>

// Private functions that Maps imports; no installed header declares them. WebKit's open-source CoreGraphicsSPI.h
// (Source/WebCore/PAL/pal/spi/cg/CoreGraphicsSPI.h, WebKit main at 038df5bca5401cb534a30f83cbd7c5da0bd9edd8)
// declares `void CGContextSetCompositeOperation(CGContextRef, CGCompositeOperation);` (line 422), the getter
// `CGCompositeOperation CGContextGetCompositeOperation(CGContextRef);` (line 414) and the enum
// `kCGCompositeCopy = 1, kCGCompositeSover = 2` (lines 110-113).
//
// The operation is a number, and its table is the blend mode as the context's state: observed on macOS 26.1 with
// our own client program (a 1x1 premultiplied RGBA bitmap, destination blue alpha 0.25, source red alpha 0.75;
// the program is in the pull request body). Operation n draws the same pixel as the public blend mode below,
// the getter returns n after the setter, a new context reports 2, SetBlendMode(m) makes the getter report that
// mode's number, and Save/RestoreGState restores it. The table is therefore the blend mode seen through this
// renumbering, and it lives in one array used in both directions:
//   0 Clear, 1 Copy, 2 Normal (source over), 3 SourceIn, 4 SourceOut, 5 SourceAtop, 6 DestinationOver,
//   7 DestinationIn, 8 DestinationOut, 9 DestinationAtop, 10 XOR, 11 PlusDarker, 12 PlusLighter, 13 Multiply,
//   14 Screen, then Overlay to Luminosity (15 to 27) in CGBlendMode order.
// WebKit's call sites agree for the two numbers it uses (kCGCompositeSover is source-over, GraphicsContextCocoa.mm
// :139,149; kCGCompositeCopy replaces the destination, WKGraphics.mm:36-59).
//
// On the Mac, operations 28 to 40 and -1 and a NULL context crash the setter (SIGSEGV; larger numbers were not
// tried). We abort with a message for any operation at or above 28 or below 0, and for a NULL context. The
// getter's behaviour for a NULL context, and for a blend mode outside 0..27 (reachable by casting a number to
// CGBlendMode), was not observed: GUESS, NEEDS-REAL-MAC, it aborts with a message that says so.
static const CGBlendMode modeForOperation[] = {
    kCGBlendModeClear, kCGBlendModeCopy, kCGBlendModeNormal, kCGBlendModeSourceIn, kCGBlendModeSourceOut,
    kCGBlendModeSourceAtop, kCGBlendModeDestinationOver, kCGBlendModeDestinationIn, kCGBlendModeDestinationOut,
    kCGBlendModeDestinationAtop, kCGBlendModeXOR, kCGBlendModePlusDarker, kCGBlendModePlusLighter,
    kCGBlendModeMultiply, kCGBlendModeScreen, kCGBlendModeOverlay, kCGBlendModeDarken, kCGBlendModeLighten,
    kCGBlendModeColorDodge, kCGBlendModeColorBurn, kCGBlendModeSoftLight, kCGBlendModeHardLight,
    kCGBlendModeDifference, kCGBlendModeExclusion, kCGBlendModeHue, kCGBlendModeSaturation, kCGBlendModeColor,
    kCGBlendModeLuminosity,
};
#define OPERATION_COUNT (sizeof modeForOperation / sizeof modeForOperation[0])

// observedOnMac: the Mac was seen to crash on this input; otherwise the abort is our own choice (GUESS).
static void failLoud(const char *function, const char *reason, int value, int observedOnMac)
{
    fprintf(stderr, "CoreGraphics: %s: %s (%d); %s\n", function, reason, value,
            observedOnMac ? "the Mac crashes here" : "not observed on the Mac, aborting (GUESS, NEEDS-REAL-MAC)");
    abort();
}

COREGRAPHICS_EXPORT void CGContextSetCompositeOperation(CGContextRef context, int operation)
{
    if (context == NULL)
        failLoud("CGContextSetCompositeOperation", "NULL context", 0, 1);
    // the size_t cast alone already rejects a negative operation; the explicit test is for the reader
    if (operation < 0 || (size_t)operation >= OPERATION_COUNT)
        failLoud("CGContextSetCompositeOperation", "operation out of range", operation, 1);
    CGContextSetBlendMode(context, modeForOperation[operation]);
}

COREGRAPHICS_EXPORT int CGContextGetCompositeOperation(CGContextRef context)
{
    if (context == NULL)
        failLoud("CGContextGetCompositeOperation", "NULL context", 0, 0);
    CGBlendMode mode = (CGBlendMode)O2GStateBlendMode(O2ContextCurrentGState((O2ContextRef)context));
    for (size_t operation = 0; operation < OPERATION_COUNT; operation++)
        if (modeForOperation[operation] == mode)
            return (int)operation;
    failLoud("CGContextGetCompositeOperation", "blend mode without an operation", (int)mode, 0);
    return -1;
}
