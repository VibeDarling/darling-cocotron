/* Copyright (c) 2006-2008 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <CoreText/KTFont.h>

@implementation KTFont

- initWithFont: (CGFontRef) font size: (CGFloat) size {
    _font = CGFontRetain(font);
    _size = size;
    return self;
}

- (void) dealloc {
    CGFontRelease(_font);
    [super dealloc];
}

- (CFStringRef) copyName {
    return CGFontCopyFullName(_font);
}

- (CGFontRef) cgFont {
    return _font;
}

- (CGFloat) pointSize {
    return _size;
}

// The text system (NSTypesetter/NSLayoutManager) queries glyph advances on whatever concrete
// font object it holds. Normally that is NSFont, which AppKit registers as CoreText's concrete
// class, but a font can be created before that registration lands, in which case every font is
// a KTFont. Answer the query here too so the text system works with either class, mirroring
// -[NSFont positionOfGlyph:precededByGlyph:isNominal:]. A KTFont is a valid CTFontRef by
// contract (it answers -cgFont and -pointSize), so the CoreText call works on it directly.
- (NSPoint) positionOfGlyph: (NSUInteger) current
            precededByGlyph: (NSUInteger) previous
                  isNominal: (BOOL *) isNominalp
{
    *isNominalp = YES;
    if (current == CGNullGlyph)
        return CGPointZero;
    CGGlyph glyph = (CGGlyph) current;
    CGSize advance = CGSizeZero;
    CTFontGetAdvancesForGlyphs((CTFontRef) self, kCTFontOrientationDefault, &glyph, &advance, 1);
    return CGPointMake(advance.width, advance.height);
}

@end
