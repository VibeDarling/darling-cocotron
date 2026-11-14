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

#import <Foundation/Foundation.h>
#import <QuartzCore/CABase.h>

CA_EXPORT NSString *const kCAFilterAlphaThreshold;
CA_EXPORT NSString *const kCAFilterAverageColor;
CA_EXPORT NSString *const kCAFilterColorBrightness;
CA_EXPORT NSString *const kCAFilterColorContrast;
CA_EXPORT NSString *const kCAFilterColorHueRotate;
CA_EXPORT NSString *const kCAFilterColorInvert;
CA_EXPORT NSString *const kCAFilterColorMatrix;
CA_EXPORT NSString *const kCAFilterColorMonochrome;
CA_EXPORT NSString *const kCAFilterColorSaturate;
CA_EXPORT NSString *const kCAFilterCurves;
CA_EXPORT NSString *const kCAFilterGaussianBlur;
CA_EXPORT NSString *const kCAFilterLuminanceCurveMap;
CA_EXPORT NSString *const kCAFilterLuminanceToAlpha;
CA_EXPORT NSString *const kCAFilterMultiplyBlendMode;
CA_EXPORT NSString *const kCAFilterMultiplyColor;
CA_EXPORT NSString *const kCAFilterVariableBlur;
CA_EXPORT NSString *const kCAFilterVibrantColorMatrix;

// Private names QuartzCore exports that clients such as WebKit declare themselves. WebKit's declarations give
// the names and the type (NSString); the string values are a GUESS, see CAFilter.m.
CA_EXPORT NSString *const kCAFilterPlusD;
CA_EXPORT NSString *const kCAFilterPlusL;
CA_EXPORT NSString *const kCAFilterColorBlendMode;
CA_EXPORT NSString *const kCAFilterColorBurnBlendMode;
CA_EXPORT NSString *const kCAFilterColorDodgeBlendMode;
CA_EXPORT NSString *const kCAFilterDarkenBlendMode;
CA_EXPORT NSString *const kCAFilterDarkenSourceOver;
CA_EXPORT NSString *const kCAFilterDestOut;
CA_EXPORT NSString *const kCAFilterDifferenceBlendMode;
CA_EXPORT NSString *const kCAFilterDivideBlendMode;
CA_EXPORT NSString *const kCAFilterExclusionBlendMode;
CA_EXPORT NSString *const kCAFilterHardLightBlendMode;
CA_EXPORT NSString *const kCAFilterHueBlendMode;
CA_EXPORT NSString *const kCAFilterLightenBlendMode;
CA_EXPORT NSString *const kCAFilterLightenSourceOver;
CA_EXPORT NSString *const kCAFilterLinearBurnBlendMode;
CA_EXPORT NSString *const kCAFilterLinearDodgeBlendMode;
CA_EXPORT NSString *const kCAFilterLinearLightBlendMode;
CA_EXPORT NSString *const kCAFilterLuminosityBlendMode;
CA_EXPORT NSString *const kCAFilterMaximum;
CA_EXPORT NSString *const kCAFilterMinimum;
CA_EXPORT NSString *const kCAFilterMultiply;
CA_EXPORT NSString *const kCAFilterNormalBlendMode;
CA_EXPORT NSString *const kCAFilterOverlayBlendMode;
CA_EXPORT NSString *const kCAFilterPinLightBlendMode;
CA_EXPORT NSString *const kCAFilterSaturationBlendMode;
CA_EXPORT NSString *const kCAFilterScreenBlendMode;
CA_EXPORT NSString *const kCAFilterSoftLightBlendMode;
CA_EXPORT NSString *const kCAFilterSubtractBlendMode;
CA_EXPORT NSString *const kCAFilterSubtractD;
CA_EXPORT NSString *const kCAFilterSubtractS;

CA_EXPORT NSString *const kCAFilterInputAlphaValues;
CA_EXPORT NSString *const kCAFilterInputAmount;
CA_EXPORT NSString *const kCAFilterInputAngle;
CA_EXPORT NSString *const kCAFilterInputBias;
CA_EXPORT NSString *const kCAFilterInputBlueValues;
CA_EXPORT NSString *const kCAFilterInputColor;
CA_EXPORT NSString *const kCAFilterInputColorMatrix;
CA_EXPORT NSString *const kCAFilterInputDither;
CA_EXPORT NSString *const kCAFilterInputGreenValues;
CA_EXPORT NSString *const kCAFilterInputHardEdges;
CA_EXPORT NSString *const kCAFilterInputNormalizeEdges;
CA_EXPORT NSString *const kCAFilterInputPremultipliedValues;
CA_EXPORT NSString *const kCAFilterInputRadius;
CA_EXPORT NSString *const kCAFilterInputRedValues;
CA_EXPORT NSString *const kCAFilterInputValues;

// Private SPI, kept out of the public headers as on macOS: clients declare
// CAFilter themselves. Inputs are stored with key-value coding under their
// input keys; CARenderer does not apply filters yet.
@interface CAFilter : NSObject <NSCopying> {
    NSString *_type;
    NSString *_name;
    BOOL _enabled;
    NSMutableDictionary *_inputs;
}

+ (instancetype) filterWithType: (NSString *) type;
- (instancetype) initWithType: (NSString *) type;

@property(readonly, copy) NSString *type;
@property(copy) NSString *name;
@property(getter=isEnabled) BOOL enabled;

@end
