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
#include <CoreGraphics/CGColorSpace.h>
#include <CoreGraphics/CGWindow.h>
#include <CoreGraphics/CoreGraphicsPrivate.h>
#include <stdio.h>
#include <stdlib.h>

// Functions that guest applications import and Cocotron cannot answer. The private ones have no public
// documentation of their arguments or results, so a call prints the name and aborts instead of answering
// with an invented value.
#define CG_FAIL_LOUD(name) \
    COREGRAPHICS_EXPORT void name(void) { \
        fprintf(stderr, "CoreGraphics: " #name " is not implemented\n"); \
        abort(); \
    }

// CGWindow.h documents this one: the description dictionaries of the selected windows of the user session.
// Apple returns NULL when there is no window server. Here a Wayland server is present, so NULL would be wrong,
// and the list of other clients' windows is not available; CGWindowListCreate, which would feed it, is a STUB.
CFArrayRef CGWindowListCopyWindowInfo(CGWindowListOption option, CGWindowID relativeToWindow)
{
    fprintf(stderr, "CoreGraphics: CGWindowListCopyWindowInfo is not implemented\n");
    abort();
}

CG_FAIL_LOUD(CGSSessionCopyAllSessionProperties)
CG_FAIL_LOUD(CGWindowContextCreate)
CG_FAIL_LOUD(CGWindowContextCreateImage)
// Public (macOS 12.0, CGColorSpace.h) with its real prototype. Cocotron has no ColorSync to read a profile
// with, so this aborts instead of returning a color space that is not the profile's.
CGColorSpaceRef CGColorSpaceCreateWithColorSyncProfile(CFTypeRef profile, CFDictionaryRef options)
{
    fprintf(stderr, "CoreGraphics: CGColorSpaceCreateWithColorSyncProfile is not implemented: Cocotron has no ColorSync\n");
    abort();
}

CG_FAIL_LOUD(CGColorSpaceCreateWithID)
CG_FAIL_LOUD(CGSGetOnScreenWindowCount)
CG_FAIL_LOUD(CGSGetOnScreenWindowList)
CG_FAIL_LOUD(CGImageWriteToFile)
CG_FAIL_LOUD(CGSDisplayStatusQuery)
CG_FAIL_LOUD(CGSCopyDisplayInfoDictionary)
CG_FAIL_LOUD(CGSCopyDisplayUUID)
CG_FAIL_LOUD(CGSGetDisplayModeDescriptionsOfLength)
CG_FAIL_LOUD(CGSSecondsSinceLastInputEvent)
CG_FAIL_LOUD(CGContextCopyDeviceColorSpace)
CG_FAIL_LOUD(CGDisplayVisualBell)
CG_FAIL_LOUD(CGSGetPerformanceData)
CG_FAIL_LOUD(CGSGetWindowTags)
CG_FAIL_LOUD(CGSHWCaptureWindowList)
// Declared in CoreGraphicsPrivate.h with its real prototype, so it is defined with it.
CGError CGSSetWindowTags(CGSConnectionID cid, CGSWindowID wid, const int tags[2], size_t tag_size)
{
    fprintf(stderr, "CoreGraphics: CGSSetWindowTags is not implemented\n");
    abort();
}
