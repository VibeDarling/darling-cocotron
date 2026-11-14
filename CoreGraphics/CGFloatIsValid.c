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

#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CoreGraphicsExport.h>
#include <math.h>
#include <stdbool.h>

// Private function that Maps imports; no installed header declares it. Observed on macOS 26.1 with our own client
// program (probe quoted in the pull request): CGFloatIsValid(CGFloat) returns 1 for every finite value (including
// -0, a subnormal, DBL_MAX and values beyond FLT_MAX) and 0 for NaN, -NaN, +infinity and -infinity, and its
// 32-bit return register holds exactly 0 or 1, so the result is a bool equal to isfinite(). CGFloat is double on
// 64-bit (public CGBase.h).
COREGRAPHICS_EXPORT bool CGFloatIsValid(CGFloat value)
{
    return isfinite(value);
}
