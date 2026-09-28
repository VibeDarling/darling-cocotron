#!/usr/bin/env ruby
# Run the actual mapping function against a real FreeType Unicode font face.
# Usage: ruby tests/font-unicode-glyphs.rb FONT_FILE [CTFont.m]
require 'tmpdir'
require 'open3'
require 'shellwords'

font = ARGV.fetch(0) { abort 'provide a font containing BMP and supplementary characters' }
source = File.read(ARGV.fetch(1, File.expand_path('../CoreText/CTFont.m', __dir__)))
method = source[/bool CTFontGetGlyphsForCharacters\(.*?^\}/m] or abort 'method not found'
harness = <<~'C'
  #include <ft2build.h>
  #include FT_FREETYPE_H
  #include <assert.h>
  #include <stdbool.h>
  #include <stdint.h>
  #include <stdio.h>
  typedef FT_Face CTFontRef;
  typedef uint16_t UniChar, CGGlyph;
  typedef long CFIndex;
  #define YES true
  static FT_Face faceForFont(CTFontRef font) { return font; }
C
harness += method
harness += <<~'C'
  static size_t encode(uint32_t cp, UniChar *chars) {
      if (cp < 0x10000) { chars[0] = cp; return 1; }
      chars[0] = 0xD800 + ((cp - 0x10000) >> 10);
      chars[1] = 0xDC00 + ((cp - 0x10000) & 1023);
      return 2;
  }
  int main(int argc, char **argv) {
      assert(argc == 2);
      FT_Library library; FT_Face face;
      assert(FT_Init_FreeType(&library) == 0);
      assert(FT_New_Face(library, argv[1], 0, &face) == 0);
      assert(FT_Select_Charmap(face, FT_ENCODING_UNICODE) == 0);
      uint32_t supplementary = 0, missing = 0;
      for (uint32_t cp = 0x10000; cp <= 0x10FFFF; cp++) {
          FT_UInt glyph = FT_Get_Char_Index(face, cp);
          if (glyph && glyph <= UINT16_MAX && !supplementary) supplementary = cp;
          if (!glyph && !missing) missing = cp;
          if (supplementary && missing) break;
      }
      assert(supplementary && missing && FT_Get_Char_Index(face, 'A'));
      CGGlyph storage[6] = {0xCAFE,0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xBEEF};
      CGGlyph *glyphs = storage + 1;
      UniChar chars[4] = {'A',0,0,'A'};
      encode(supplementary, chars + 1);
      assert(CTFontGetGlyphsForCharacters(face, chars, glyphs, 4));
      assert(glyphs[0] == FT_Get_Char_Index(face, 'A'));
      assert(glyphs[1] == FT_Get_Char_Index(face, supplementary));
      assert(glyphs[2] == 0 && glyphs[3] == glyphs[0]);
      assert(storage[0] == 0xCAFE && storage[5] == 0xBEEF);
      encode(missing, chars + 1);
      assert(!CTFontGetGlyphsForCharacters(face, chars, glyphs, 4));
      assert(glyphs[0] != 0 && glyphs[1] == 0 && glyphs[2] == 0 && glyphs[3] == glyphs[0]);

      const UniChar malformed[][4] = {
          {0xD800,'A',0xDC00,'A'}, {0xDC00,'A',0xD800,'A'},
          {'A',0xD800,0xD800,'A'}
      };
      for (size_t c = 0; c < 3; c++) {
          assert(!CTFontGetGlyphsForCharacters(face, malformed[c], glyphs, 4));
          for (size_t i = 0; i < 4; i++)
              assert(glyphs[i] == (malformed[c][i] == 'A' ? FT_Get_Char_Index(face, 'A') : 0));
      }
      UniChar high = 0xD800, low = 0xDC00;
      assert(!CTFontGetGlyphsForCharacters(face, &high, glyphs, 1) && glyphs[0] == 0);
      assert(!CTFontGetGlyphsForCharacters(face, &low, glyphs, 1) && glyphs[0] == 0);
      assert(CTFontGetGlyphsForCharacters(face, NULL, NULL, 0));
      assert(!CTFontGetGlyphsForCharacters(face, chars, glyphs, -1));
      assert(!CTFontGetGlyphsForCharacters(NULL, chars, glyphs, 4));
      assert(!CTFontGetGlyphsForCharacters(face, NULL, glyphs, 4));
      assert(!CTFontGetGlyphsForCharacters(face, chars, NULL, 4));

      // Exhaust all scalar values against this font's real cmap, including
      // absent BMP/supplementary mappings and supplementary boundary values.
      for (uint32_t cp = 0; cp <= 0x10FFFF; cp++) {
          if (cp >= 0xD800 && cp <= 0xDFFF) continue;
          size_t count = encode(cp, chars);
          FT_UInt expected = FT_Get_Char_Index(face, cp);
          if (expected > UINT16_MAX) expected = 0;
          glyphs[0] = glyphs[1] = 0xFFFF;
          bool result = CTFontGetGlyphsForCharacters(face, chars, glyphs, count);
          assert(result == (expected != 0) && glyphs[0] == expected);
          assert(count == 1 ? glyphs[1] == 0xFFFF : glyphs[1] == 0);
      }
      FT_Done_Face(face); FT_Done_FreeType(library);
      puts("All Unicode scalar mappings, missing glyphs, UTF-16 indexing and guards passed");
  }
C
flags, status = Open3.capture2e('pkg-config', '--cflags', '--libs', 'freetype2')
abort flags unless status.success?
Dir.mktmpdir('font-unicode-glyphs') do |dir|
  input = File.join(dir, 'probe.c')
  output = File.join(dir, 'probe')
  File.write(input, harness)
  log, status = Open3.capture2e(ENV.fetch('CC', 'clang'), '-std=c11', '-Wall', '-Wextra',
      '-O2', '-fsanitize=address,undefined', input, *Shellwords.split(flags), '-o', output)
  abort log unless status.success?
  log, status = Open3.capture2e(output, font)
  puts log
  abort 'probe failed' unless status.success?
end
