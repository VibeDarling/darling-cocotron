#import <AppKit/NSColor.h>
#import <Foundation/NSCoder.h>

@interface NSCoder (AppKit)
- (NSColor *) decodeNXColor;
@end

// Reads one byte of a legacy typedstream (the "c" type). NSUnarchiver has no
// public -decodeByte, so the pre-keyed decoders go through the public
// NSCoder API instead of a method only some Foundations carry.
uint8_t NSAppKitDecodeByte(NSCoder *coder);
