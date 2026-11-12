/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

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

// Darling's Foundation has a private -[NSUnarchiver decodeByte] that Apple's Foundation lacks.
// Its whole body is one decodeValuesOfObjCTypes: call.

#import <Foundation/NSCoder.h>

static inline uint8_t AKDecodeByte(NSCoder *coder) {
    uint8_t value = 0;

    [coder decodeValuesOfObjCTypes: "c", &value];

    return value;
}
