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

// Documented attribute and key names (the documentation gives the names and the CFString type). The values are
// observed on a real Mac (rung 4, macOS 26.1, our own probe symbols_d_probe1); the line of the probe output is in
// each comment.
const CFStringRef kCTFontDescriptorMatchingPercentage = CFSTR("CTFontDescriptorMatchingPercentage"); // probe1:44
const CFStringRef kCTFontDownloadableAttribute = CFSTR("NSCTFontDownloadableAttribute"); // probe1:42
const CFStringRef kCTFontDownloadedAttribute = CFSTR("NSCTFontDownloadedAttribute"); // probe1:43
const CFStringRef kCTFontOpticalSizeAttribute = CFSTR("NSCTFontOpticalSizeAttribute"); // probe1:40

// Documented string attribute names (Apple's public CoreText documentation: CFString, macOS 10.5 to 10.12). The
// documentation gives the names and the type, not the values.
// GUESS (NEEDS-REAL-MAC): each carries its own name.
const CFStringRef kCTHorizontalInVerticalFormsAttributeName = CFSTR("kCTHorizontalInVerticalFormsAttributeName");
const CFStringRef kCTStrokeColorAttributeName = CFSTR("kCTStrokeColorAttributeName");
const CFStringRef kCTTabColumnTerminatorsAttributeName = CFSTR("kCTTabColumnTerminatorsAttributeName");
const CFStringRef kCTWritingDirectionAttributeName = CFSTR("kCTWritingDirectionAttributeName");
