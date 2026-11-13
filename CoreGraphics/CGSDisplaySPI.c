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

#include <CoreGraphics/CGSDisplaySPI.h>

CGDirectDisplayID CGSMainDisplayID(void)
{
    return CGMainDisplayID();
}

CGDisplayErr CGSGetOnlineDisplayList(uint32_t maxDisplays, CGDirectDisplayID *displays, uint32_t *outDisplayCount)
{
    return CGGetOnlineDisplayList(maxDisplays, displays, outDisplayCount);
}
