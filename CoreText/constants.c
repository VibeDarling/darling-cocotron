/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFString.h>

const CFStringRef kCTFontAttributeName = CFSTR("NSFont");
const CFStringRef kCTFontSymbolicTrait = CFSTR("NSCTFontSymbolicTrait");
const CFStringRef kCTForegroundColorFromContextAttributeName = CFSTR("CTForegroundColorFromContext");
const CFStringRef kCTStrokeWidthAttributeName = CFSTR("NSStrokeWidth");
const CFStringRef kCTForegroundColorAttributeName = CFSTR("CTForegroundColor");
const CFStringRef kCTParagraphStyleAttributeName = CFSTR("NSParagraphStyle");
const CFStringRef kCTKernAttributeName = CFSTR("CTKernAttributeName");
const CFStringRef kCTLanguageAttributeName = CFSTR("CTLanguageAttributeName");
const CFStringRef kCTTypesetterOptionForcedEmbeddingLevel = CFSTR("CTTypesetterOptionForcedEmbeddingLevel");
const CFStringRef kCTVerticalFormsAttributeName = CFSTR("CTVerticalFormsAttributeName");
const CFStringRef kCTFontWeightTrait = CFSTR("NSCTFontWeightTrait");
const CFStringRef kCTFontWidthTrait = CFSTR("NSCTFontWidthTrait");
const CFStringRef kCTFontSlantTrait = CFSTR("NSCTFontSlantTrait");
const CFStringRef kCTFontOpenTypeFeatureTag = CFSTR("CTFeatureOpenTypeTag");
const CFStringRef kCTFontOpenTypeFeatureValue = CFSTR("CTFeatureOpenTypeValue");

// The content size categories (CTFont SPI; WebKit's CoreTextSPI.h declares L and XXXL as CFStringRef, and the
// Books framework BooksUI imports the other ten by name). GUESS: no permitted source gives the string values, so
// each carries its own name. Only code that compares them against these same objects works; a lookup by category
// in a table keyed with Apple's literals would miss. The real values need a real Mac.
const CFStringRef kCTFontContentSizeCategoryXS = CFSTR("kCTFontContentSizeCategoryXS");
const CFStringRef kCTFontContentSizeCategoryS = CFSTR("kCTFontContentSizeCategoryS");
const CFStringRef kCTFontContentSizeCategoryM = CFSTR("kCTFontContentSizeCategoryM");
const CFStringRef kCTFontContentSizeCategoryL = CFSTR("kCTFontContentSizeCategoryL");
const CFStringRef kCTFontContentSizeCategoryXL = CFSTR("kCTFontContentSizeCategoryXL");
const CFStringRef kCTFontContentSizeCategoryXXL = CFSTR("kCTFontContentSizeCategoryXXL");
const CFStringRef kCTFontContentSizeCategoryXXXL = CFSTR("kCTFontContentSizeCategoryXXXL");
const CFStringRef kCTFontContentSizeCategoryAccessibilityM = CFSTR("kCTFontContentSizeCategoryAccessibilityM");
const CFStringRef kCTFontContentSizeCategoryAccessibilityL = CFSTR("kCTFontContentSizeCategoryAccessibilityL");
const CFStringRef kCTFontContentSizeCategoryAccessibilityXL = CFSTR("kCTFontContentSizeCategoryAccessibilityXL");
const CFStringRef kCTFontContentSizeCategoryAccessibilityXXL = CFSTR("kCTFontContentSizeCategoryAccessibilityXXL");
const CFStringRef kCTFontContentSizeCategoryAccessibilityXXXL = CFSTR("kCTFontContentSizeCategoryAccessibilityXXXL");
