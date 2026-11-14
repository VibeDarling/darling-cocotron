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

#import <Foundation/NSObject.h>

// QuartzCore's private package class (FindMy binds it at launch). Nothing public describes its interface, so
// the class exists for clients that link it and answers no selector of its own: a message to it fails as an
// unrecognized selector instead of returning an invented answer. Its superclass is a GUESS.
@interface CAPackage : NSObject
@end

// The private package type constant FindMy imports. The public documentation has neither its type nor its value;
// GUESS: an NSString whose value is the name without its prefix.
NSString *const kCAPackageTypeCAMLBundle = @"CAMLBundle";

@implementation CAPackage
@end
