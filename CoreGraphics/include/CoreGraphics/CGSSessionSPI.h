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

#ifndef CGSSESSIONSPI_H
#define CGSSESSIONSPI_H

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphicsExport.h>

// Keys of the session property dictionaries. The "kCGSSession" spelling is the one stock applications import.
COREGRAPHICS_EXPORT const CFStringRef kCGSSessionUserNameKey;
COREGRAPHICS_EXPORT const CFStringRef kCGSSessionLongUserNameKey;

#endif
