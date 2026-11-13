#import <AppKit/NSColor.h>
#import <Foundation/NSCoder.h>

@interface NSCoder (AppKit)
- (NSColor *) decodeNXColor;
@end

// Reads one byte of a legacy typedstream (the "c" type). NSUnarchiver has no
// public -decodeByte, so the pre-keyed decoders go through the public
// NSCoder API instead of a method only some Foundations carry. It is inline
// and built on public API alone, so it is no symbol of any image: AppKit and
// the UIFoundation objects (NSFont) share it without one importing the other.
static inline uint8_t NSAppKitDecodeByte(NSCoder *coder) {
    uint8_t value = 0;
    [coder decodeValueOfObjCType: "c" at: &value];
    return value;
}
