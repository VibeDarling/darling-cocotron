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

#ifndef CGSDISPLAYSPI_H
#define CGSDISPLAYSPI_H

#include <CoreGraphics/CGDirectDisplay.h>
#include <CoreGraphics/CGError.h>
#include <CoreGraphics/CoreGraphicsExport.h>

// Window-server names of two documented display functions. Prototypes: WebKit's CoreGraphicsSPI.h and the
// CGSInternal header collection (CGSDisplays.h).
COREGRAPHICS_EXPORT CGDirectDisplayID CGSMainDisplayID(void);
COREGRAPHICS_EXPORT CGDisplayErr CGSGetOnlineDisplayList(uint32_t maxDisplays, CGDirectDisplayID *displays, uint32_t *outDisplayCount);

#endif
