#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGColorSpace.h>
#include <math.h>
#include <stdbool.h>

// Transfer characteristics and primaries of the RGB color spaces Onyx2D can
// create, from the published definitions: sRGB (IEC 61966-2-1), Display P3
// (DCI-P3 primaries with the D65 white point and the sRGB transfer curve) and
// ITU-R BT.2100 PQ (BT.2020 primaries, SMPTE ST 2084 transfer).

typedef enum {
    TransferSRGB,
    TransferLinear,
    TransferPQ,
    TransferHLG, // Onyx2D cannot create an HLG space yet
} Transfer;

typedef struct {
    double x, y;
} Chromaticity;

typedef struct {
    Chromaticity red, green, blue;
} Primaries;

typedef struct {
    const Primaries *primaries;
    Transfer transfer;
    bool extended;
} RGBSpace;

static const Chromaticity kWhiteD65 = {0.3127, 0.3290};
static const Primaries kPrimariesSRGB = {{0.640, 0.330}, {0.300, 0.600}, {0.150, 0.060}};
static const Primaries kPrimariesDisplayP3 = {{0.680, 0.320}, {0.265, 0.690}, {0.150, 0.060}};
static const Primaries kPrimariesBT2020 = {{0.708, 0.292}, {0.170, 0.797}, {0.131, 0.046}};

static bool describeNamedSpace(CFStringRef name, RGBSpace *out) {
    static const struct {
        const CFStringRef *name;
        RGBSpace space;
    } table[] = {
        {&kCGColorSpaceSRGB, {&kPrimariesSRGB, TransferSRGB, false}},
        {&kCGColorSpaceExtendedSRGB, {&kPrimariesSRGB, TransferSRGB, true}},
        {&kCGColorSpaceLinearSRGB, {&kPrimariesSRGB, TransferLinear, false}},
        {&kCGColorSpaceExtendedLinearSRGB, {&kPrimariesSRGB, TransferLinear, true}},
        {&kCGColorSpaceDisplayP3, {&kPrimariesDisplayP3, TransferSRGB, false}},
        {&kCGColorSpaceExtendedDisplayP3, {&kPrimariesDisplayP3, TransferSRGB, true}},
        {&kCGColorSpaceLinearDisplayP3, {&kPrimariesDisplayP3, TransferLinear, false}},
        {&kCGColorSpaceExtendedLinearDisplayP3, {&kPrimariesDisplayP3, TransferLinear, true}},
        {&kCGColorSpaceITUR_2100_PQ, {&kPrimariesBT2020, TransferPQ, false}},
    };
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if (CFEqual(name, *table[i].name)) {
            *out = table[i].space;
            return true;
        }
    }
    return false;
}

// Unnamed device RGB (what CGColorCreateGenericRGB and
// CGColorSpaceCreateDeviceRGB use) is treated as sRGB.
static bool describeRGBSpace(CGColorSpaceRef space, RGBSpace *out) {
    if (space == NULL || CGColorSpaceGetModel(space) != kCGColorSpaceModelRGB)
        return false;
    CFStringRef name = CGColorSpaceGetName(space);
    if (name == NULL) {
        *out = (RGBSpace){&kPrimariesSRGB, TransferSRGB, false};
        return true;
    }
    return describeNamedSpace(name, out);
}

bool CGColorSpaceUsesITUR_2100TF(CGColorSpaceRef space) {
    RGBSpace rgb;
    return describeRGBSpace(space, &rgb) &&
           (rgb.transfer == TransferPQ || rgb.transfer == TransferHLG);
}

bool CGColorSpaceIsHLGBased(CGColorSpaceRef space) {
    RGBSpace rgb;
    return describeRGBSpace(space, &rgb) && rgb.transfer == TransferHLG;
}

// Gamut-only primaries of named RGB spaces that Onyx2D can create but whose transfer functions the conversion
// code above does not model. They come from the published definitions: Adobe RGB (1998), DCI-P3 (the same
// primaries as Display P3), ITU-R BT.709 (the sRGB primaries), ITU-R BT.2020 and ROMM RGB (ISO 22028-2).
static const Primaries kPrimariesAdobeRGB = {{0.640, 0.330}, {0.210, 0.710}, {0.150, 0.060}};
static const Primaries kPrimariesROMMRGB = {{0.7347, 0.2653}, {0.1596, 0.8404}, {0.0366, 0.0001}};
// The 1953 NTSC primaries, the reference gamut of CGColorSpaceIsWideGamutRGB.
static const Primaries kPrimariesNTSC1953 = {{0.670, 0.330}, {0.210, 0.710}, {0.140, 0.080}};

static const Primaries *gamutOnlyPrimaries(CFStringRef name) {
    static const struct {
        const CFStringRef *name;
        const Primaries *primaries;
    } table[] = {
        {&kCGColorSpaceAdobeRGB1998, &kPrimariesAdobeRGB},
        {&kCGColorSpaceDCIP3, &kPrimariesDisplayP3},
        {&kCGColorSpaceITUR_709, &kPrimariesSRGB},
        {&kCGColorSpaceITUR_2020, &kPrimariesBT2020},
        {&kCGColorSpaceExtendedLinearITUR_2020, &kPrimariesBT2020},
        {&kCGColorSpaceROMMRGB, &kPrimariesROMMRGB},
    };
    for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
        if (CFEqual(name, *table[i].name))
            return table[i].primaries;
    }
    return NULL;
}

static double gamutArea(const Primaries *p) {
    return fabs(p->red.x * (p->green.y - p->blue.y) + p->green.x * (p->blue.y - p->red.y) +
                p->blue.x * (p->red.y - p->green.y)) / 2;
}

// Public (macOS 10.12): "true if the color space is greater than 85% of the NTSC gamut". GUESS: the size of a
// gamut is read as the area of its primaries' triangle in CIE 1931 xy, relative to the NTSC 1953 triangle (the
// usual "percent of NTSC" figure; sRGB is 71%, Display P3 96%, Adobe RGB 95%). A space whose primaries are
// not known here (generic RGB, non-RGB models, NULL) is not wide gamut. NEEDS-REAL-MAC for spaces near 85%.
bool CGColorSpaceIsWideGamutRGB(CGColorSpaceRef space) {
    RGBSpace rgb;
    const Primaries *primaries = NULL;
    if (describeRGBSpace(space, &rgb)) {
        primaries = rgb.primaries;
    } else if (space != NULL && CGColorSpaceGetModel(space) == kCGColorSpaceModelRGB) {
        CFStringRef name = CGColorSpaceGetName(space);
        primaries = name != NULL ? gamutOnlyPrimaries(name) : NULL;
    }
    return primaries != NULL && gamutArea(primaries) > 0.85 * gamutArea(&kPrimariesNTSC1953);
}

// Observed on macOS 26.1 (probe 12, section 3, answers for 15 named and 5 created spaces): true for
// kCGColorSpaceITUR_2100_PQ, kCGColorSpaceITUR_2100_HLG and kCGColorSpaceDisplayP3_PQ, false for every other space
// probed (sRGB, linear and extended sRGB, Display P3, ITU-R 2020, gray, CMYK, Lab, XYZ, indexed, pattern). That is
// the ITU-R 2100 transfer function test. Not observed, GUESS: a NULL space is false; kCGColorSpaceDisplayP3_PQ does
// not exist in Cocotron yet, so that one name is not covered.
bool CGColorSpaceIsHDR(CGColorSpaceRef space) {
    return CGColorSpaceUsesITUR_2100TF(space);
}

// Observed on macOS 26.1 (probe 12, section 3): true for every RGB, gray, CMYK, Lab and XYZ space probed, false for
// an indexed and a pattern space. Not observed, GUESS: a NULL space is false, and a DeviceN or unknown model is true.
bool CGColorSpaceSupportsOutput(CGColorSpaceRef space) {
    if (space == NULL)
        return false;
    CGColorSpaceModel model = CGColorSpaceGetModel(space);
    return model != kCGColorSpaceModelIndexed && model != kCGColorSpaceModelPattern;
}

static double srgbToLinear(double v) {
    double a = fabs(v);
    double linear = a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4);
    return copysign(linear, v);
}

static double linearToSRGB(double v) {
    double a = fabs(v);
    double encoded = a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055;
    return copysign(encoded, v);
}

static void invert3x3(double m[3][3], double inv[3][3]) {
    double det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
                 m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
                 m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
    inv[0][0] = (m[1][1] * m[2][2] - m[1][2] * m[2][1]) / det;
    inv[0][1] = (m[0][2] * m[2][1] - m[0][1] * m[2][2]) / det;
    inv[0][2] = (m[0][1] * m[1][2] - m[0][2] * m[1][1]) / det;
    inv[1][0] = (m[1][2] * m[2][0] - m[1][0] * m[2][2]) / det;
    inv[1][1] = (m[0][0] * m[2][2] - m[0][2] * m[2][0]) / det;
    inv[1][2] = (m[0][2] * m[1][0] - m[0][0] * m[1][2]) / det;
    inv[2][0] = (m[1][0] * m[2][1] - m[1][1] * m[2][0]) / det;
    inv[2][1] = (m[0][1] * m[2][0] - m[0][0] * m[2][1]) / det;
    inv[2][2] = (m[0][0] * m[1][1] - m[0][1] * m[1][0]) / det;
}

// RGB -> XYZ matrix: each primary's XYZ at Y = 1, scaled so that RGB (1,1,1)
// maps to the D65 white point.
static void rgbToXYZ(const Primaries *p, double m[3][3]) {
    const Chromaticity *c[3] = {&p->red, &p->green, &p->blue};
    double xyz[3][3], inv[3][3];
    for (int i = 0; i < 3; i++) {
        xyz[0][i] = c[i]->x / c[i]->y;
        xyz[1][i] = 1;
        xyz[2][i] = (1 - c[i]->x - c[i]->y) / c[i]->y;
    }
    double w[3] = {kWhiteD65.x / kWhiteD65.y, 1, (1 - kWhiteD65.x - kWhiteD65.y) / kWhiteD65.y};
    invert3x3(xyz, inv);
    for (int col = 0; col < 3; col++) {
        double scale = inv[col][0] * w[0] + inv[col][1] * w[1] + inv[col][2] * w[2];
        for (int r = 0; r < 3; r++)
            m[r][col] = xyz[r][col] * scale;
    }
}

// Both spaces use the D65 white point, so no chromatic adaptation is needed and
// every rendering intent maps colorimetrically; out-of-gamut values are clipped
// unless the destination is an extended space.
CGColorRef CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef space,
                                                   CGColorRenderingIntent intent,
                                                   CGColorRef color,
                                                   CFDictionaryRef options)
{
    if (space == NULL || color == NULL)
        return NULL;

    RGBSpace dst;
    if (!describeRGBSpace(space, &dst) || dst.transfer == TransferPQ || dst.transfer == TransferHLG)
        return NULL;

    CGColorSpaceRef srcSpace = CGColorGetColorSpace(color);
    const CGFloat *c = CGColorGetComponents(color);
    double linear[3];
    RGBSpace src;
    if (CGColorSpaceGetModel(srcSpace) == kCGColorSpaceModelMonochrome &&
        CGColorSpaceGetName(srcSpace) == NULL) {
        // Device gray: an achromatic sRGB-encoded value.
        src = (RGBSpace){&kPrimariesSRGB, TransferSRGB, false};
        linear[0] = linear[1] = linear[2] = srgbToLinear(c[0]);
    } else if (describeRGBSpace(srcSpace, &src) && src.transfer != TransferPQ &&
               src.transfer != TransferHLG) {
        for (int i = 0; i < 3; i++)
            linear[i] = src.transfer == TransferSRGB ? srgbToLinear(c[i]) : c[i];
    } else {
        return NULL;
    }

    double out[3] = {linear[0], linear[1], linear[2]};
    if (src.primaries != dst.primaries) {
        double toXYZ[3][3], fromXYZ[3][3], dstToXYZ[3][3];
        rgbToXYZ(src.primaries, toXYZ);
        rgbToXYZ(dst.primaries, dstToXYZ);
        invert3x3(dstToXYZ, fromXYZ);
        double xyz[3];
        for (int r = 0; r < 3; r++)
            xyz[r] = toXYZ[r][0] * linear[0] + toXYZ[r][1] * linear[1] + toXYZ[r][2] * linear[2];
        for (int r = 0; r < 3; r++)
            out[r] = fromXYZ[r][0] * xyz[0] + fromXYZ[r][1] * xyz[1] + fromXYZ[r][2] * xyz[2];
    }

    CGFloat components[4];
    for (int i = 0; i < 3; i++) {
        double v = dst.transfer == TransferSRGB ? linearToSRGB(out[i]) : out[i];
        if (!dst.extended)
            v = fmin(fmax(v, 0), 1);
        components[i] = v;
    }
    components[3] = CGColorGetAlpha(color);
    return CGColorCreate(space, components);
}
