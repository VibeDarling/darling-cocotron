/*
 * A subset of the AAT font feature types and selectors, with the numbers of Apple's
 * TrueType Font Feature Registry (TrueType Reference Manual, chapter "Font Feature Registry").
 * Apps pass them in a font descriptor's feature settings, e.g. monospaced digits.
 */
#ifndef CORETEXT_SFNTLAYOUTTYPES_H
#define CORETEXT_SFNTLAYOUTTYPES_H

enum {
	kVerticalPositionType = 10,
	kFractionsType = 11,
	kNumberSpacingType = 6,
	kNumberCaseType = 21,
	kLowerCaseType = 37,
	kUpperCaseType = 38,
};

/* kNumberSpacingType */
enum {
	kMonospacedNumbersSelector = 0,
	kProportionalNumbersSelector = 1,
	kThirdWidthNumbersSelector = 2,
	kQuarterWidthNumbersSelector = 3,
};

/* kNumberCaseType */
enum {
	kLowerCaseNumbersSelector = 0,
	kUpperCaseNumbersSelector = 1,
};

/* kFractionsType */
enum {
	kNoFractionsSelector = 0,
	kVerticalFractionsSelector = 1,
	kDiagonalFractionsSelector = 2,
};

/* kVerticalPositionType */
enum {
	kNormalPositionSelector = 0,
	kSuperiorsSelector = 1,
	kInferiorsSelector = 2,
	kOrdinalsSelector = 3,
	kScientificInferiorsSelector = 4,
};

/* kLowerCaseType */
enum {
	kDefaultLowerCaseSelector = 0,
	kLowerCaseSmallCapsSelector = 1,
	kLowerCasePetiteCapsSelector = 2,
};

/* kUpperCaseType */
enum {
	kDefaultUpperCaseSelector = 0,
	kUpperCaseSmallCapsSelector = 1,
	kUpperCasePetiteCapsSelector = 2,
};

#endif /* CORETEXT_SFNTLAYOUTTYPES_H */
