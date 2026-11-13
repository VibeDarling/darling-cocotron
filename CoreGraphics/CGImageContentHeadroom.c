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

#include <CoreGraphics/CGImage.h>

// Content headroom is the HDR range an image's values may use above SDR white. Cocotron renders every image
// as SDR and keeps no headroom per image, so the headroom argument has no effect: the result is a copy.
CGImageRef CGImageCreateCopyWithContentHeadroom(float headroom, CGImageRef image)
{
    (void) headroom;
    return CGImageCreateCopy(image);
}
