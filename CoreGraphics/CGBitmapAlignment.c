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
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// Private function that Maps imports; it has no prototype in any installed header. Its prototype and meaning
// come from the open-source Quartz reimplementation freequartz (Apache-2.0, CGBitmapContext.c): it takes a row
// length in bytes and returns it rounded up to a multiple of an alignment. The public CGBitmapContextCreate
// documentation only requires bytesPerRow >= width * bytes per pixel, so any rounding up satisfies it.
//
// The alignment is 32 bytes and 0 maps to 0: observed by calling the function in a program of our own on a real
// Mac (macOS 26.1), 36 inputs from 0 to 10000 (rung 4, mac-probe/darling_probe3.txt Part 2). Only the overflow
// case is not covered by any source, so it fails loudly instead of wrapping to a smaller length (GUESS).
#define CG_BITMAP_ALIGNMENT 32

COREGRAPHICS_EXPORT size_t CGBitmapGetAlignedBytesPerRow(size_t bytesPerRow)
{
    if (bytesPerRow > SIZE_MAX - (CG_BITMAP_ALIGNMENT - 1)) {
        fprintf(stderr, "CoreGraphics: CGBitmapGetAlignedBytesPerRow: length does not fit in size_t\n");
        abort();
    }
    return (bytesPerRow + (CG_BITMAP_ALIGNMENT - 1)) & ~(size_t)(CG_BITMAP_ALIGNMENT - 1);
}
