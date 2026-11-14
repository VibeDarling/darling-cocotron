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

#import <AppKit/AppKitExport.h>
#include <stdio.h>
#include <stdlib.h>

// Private AppKit image function that a stock application imports. No public header or document gives its
// arguments, result or meaning, so it is exported with no signature (void, GUESS: the real one takes arguments
// and returns a value) and a call prints the name and aborts instead of answering with an invented value.
// Whether the application binds it as a function or as data is not known (GUESS: a function).
static void notImplemented(const char *name) __attribute__((noreturn));

static void notImplemented(const char *name) {
    fprintf(stderr, "AppKit: %s is not implemented\n", name);
    abort();
}

// Imported by TV. The C name starts with an underscore, so the binary symbol starts with two.
APPKIT_EXPORT void _NSCenteredRectForImage(void) {
    notImplemented("_NSCenteredRectForImage");
}
