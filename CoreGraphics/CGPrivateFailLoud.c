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

CG_FAIL_LOUD(CGBitmapContextCreateWithDictionary)  // ColorSync Utility
CG_FAIL_LOUD(CGSCopySpaces)                        // QuickTime Player
