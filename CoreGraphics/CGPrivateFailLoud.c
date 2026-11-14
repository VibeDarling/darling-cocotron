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

#include <CoreGraphics/CoreGraphicsExport.h>
#include <stdio.h>
#include <stdlib.h>

// Private functions that stock applications import at launch. No permitted source documents their arguments or
// results, so a call prints the name and aborts instead of answering with an invented value. They have no
// prototype anywhere: a caller built against the macOS SDK brings its own.
#define CG_FAIL_LOUD(name) \
    COREGRAPHICS_EXPORT void name(void) { \
        fprintf(stderr, "CoreGraphics: " #name " is not implemented\n"); \
        abort(); \
    }

CG_FAIL_LOUD(CGBitmapGetAlignedBytesPerRow)        // Maps
CG_FAIL_LOUD(CGBitmapContextCreateWithDictionary)  // ColorSync Utility
CG_FAIL_LOUD(CGSCopySpaces)                        // QuickTime Player

// The window server (CGS) calls QuickTime Player, TV and ColorSync Utility import.
CG_FAIL_LOUD(CGSRegisterConnectionNotifyProc)
CG_FAIL_LOUD(CGSRemoveConnectionNotifyProc)
CG_FAIL_LOUD(CGSSpaceCreate)
CG_FAIL_LOUD(CGSSpaceDestroy)
CG_FAIL_LOUD(CGSSpaceSetAbsoluteLevel)
CG_FAIL_LOUD(CGSShowSpaces)
CG_FAIL_LOUD(CGSHideSpaces)
CG_FAIL_LOUD(CGSRemoveWindowsFromSpaces)
CG_FAIL_LOUD(CGSSetHotKey)
CG_FAIL_LOUD(CGSSetHotKeyEnabled)
CG_FAIL_LOUD(CGSRemoveHotKey)
CG_FAIL_LOUD(CGSIsZoomed)
CG_FAIL_LOUD(CGSUnionRegion)
CG_FAIL_LOUD(CGSOffsetRegion)
CG_FAIL_LOUD(CGSReleaseRegion)
CG_FAIL_LOUD(CGSGetRegionBounds)
CG_FAIL_LOUD(CGSCopySpecifiedWindowShape)
CG_FAIL_LOUD(CGSSetWindowCaptureExcludeShape)
CG_FAIL_LOUD(CGSInputModifierKeyState)
CG_FAIL_LOUD(CGSSetCursorFromData)
CG_FAIL_LOUD(CGSSetSystemDefinedCursor)
CG_FAIL_LOUD(CGSSetEventCapture)
CG_FAIL_LOUD(CGSCaptureWindowsContentsToRectWithOptions)

// Other private or SPI functions ColorSync Utility, TV, Freeform, Photos and iPhone Mirroring import.
CG_FAIL_LOUD(CGImageGetData)
CG_FAIL_LOUD(CGImageHasAlpha)
CG_FAIL_LOUD(CGContextGetType)
CG_FAIL_LOUD(CGContextGetAlpha)
CG_FAIL_LOUD(CGContextGetInterpolationQualityRange)
CG_FAIL_LOUD(CGContextSetInterpolationQualityRange)
CG_FAIL_LOUD(CGContextDrawPDFPageInRect2)
CG_FAIL_LOUD(CGColorTransformCreate)
CG_FAIL_LOUD(CGColorTransformRelease)
CG_FAIL_LOUD(CGColorTransformGetColorSpace)
CG_FAIL_LOUD(CGColorTransformConvertImage)
CG_FAIL_LOUD(CGColorTransformCreateCodeFragment)
CG_FAIL_LOUD(CGColorCodeFragmentRelease)
CG_FAIL_LOUD(CGColorCodeFragmentGetTextureData)
CG_FAIL_LOUD(CGColorSpaceCopyColorSyncProfile)
CG_FAIL_LOUD(CGColorSpaceGetType)
CG_FAIL_LOUD(CGColorSpaceGetProcessColorModel)
CG_FAIL_LOUD(CGColorSpaceEqualToColorSpace)
CG_FAIL_LOUD(CGColorSpaceConcatenate)
CG_FAIL_LOUD(CGColorSpaceCopyICCProfileDescription)
CG_FAIL_LOUD(CGImageCreateCopyWithRenderingIntent)
CG_FAIL_LOUD(CGEventSetWindowLocation)
CG_FAIL_LOUD(CGPDFDocumentCopyOutputIntents)

// Public, but the documentation does not say which color spaces they answer true for (Freeform, ColorSync
// Utility); NEEDS-REAL-MAC, see the pull request.
CG_FAIL_LOUD(CGColorSpaceSupportsOutput)
CG_FAIL_LOUD(CGColorSpaceIsHDR)
