#!/usr/bin/env ruby
# Execute the actual CTFontDrawGlyphs body against instrumented CG calls.
# This verifies dispatch/ownership/state handling, not rasterization or ABI.
require 'tmpdir'
require 'open3'

source = File.read(ARGV.fetch(0, File.expand_path('../CoreText/CTFont.m', __dir__)))
method = source[/void CTFontDrawGlyphs\(.*?^\}/m] or abort 'method not found'
harness = <<~'C'
  #include <assert.h>
  #include <stddef.h>
  #include <stdio.h>
  typedef unsigned short CGGlyph;
  typedef struct { double x, y; } CGPoint;
  typedef struct Font { int references; double size; } *CTFontRef, *CGFontRef;
  typedef struct Context { CGFontRef font; double size; int marker; } *CGContextRef;
  static struct Context saved;
  static int step, draws, copies, fail_copy;
  static CTFontRef expected_font;
  static const CGGlyph *expected_glyphs;
  static const CGPoint *expected_positions;
  static size_t expected_count;
  static CGFontRef CTFontCopyGraphicsFont(CTFontRef font, void *attributes) {
      assert(font == expected_font && attributes == NULL);
      copies++;
      if (fail_copy) return NULL;
      assert(step++ == 0);
      font->references++;
      return font;
  }
  static double CTFontGetSize(CTFontRef font) { return font->size; }
  static void CGContextSaveGState(CGContextRef context) {
      assert(step++ == 1); saved = *context;
  }
  static void CGContextSetFont(CGContextRef context, CGFontRef font) {
      assert(step++ == 2); context->font = font;
  }
  static void CGContextSetFontSize(CGContextRef context, double size) {
      assert(step++ == 3); context->size = size;
  }
  static void CGContextShowGlyphsAtPositions(CGContextRef context,
          const CGGlyph *glyphs, const CGPoint *positions, size_t count) {
      assert(step++ == 4);
      assert(context->font == expected_font);
      assert(context->size == expected_font->size);
      assert(glyphs == expected_glyphs && positions == expected_positions);
      assert(count == expected_count);
      context->marker = 99;
      draws++;
  }
  static void CGContextRestoreGState(CGContextRef context) {
      assert(step++ == 5); *context = saved;
  }
  static void CGFontRelease(CGFontRef font) {
      assert(step++ == 6); assert(font == expected_font); font->references--;
  }
C
harness += method
harness += <<~'C'
  int main(void) {
      struct Font font = {1, 17.5}, original = {1, 8};
      struct Context context = {&original, 11.25, 42};
      const CGGlyph glyphs[] = {7, 0, 65535};
      const CGPoint positions[] = {{-3, 8}, {7.5, -4}, {22, 1}};
      expected_font = &font; expected_glyphs = glyphs; expected_positions = positions;
      for (size_t count = 1; count <= 3; count++) {
          expected_count = count; step = 0;
          CTFontDrawGlyphs(&font, glyphs, positions, count, &context);
          assert(step == 7 && draws == count && copies == count);
          assert(font.references == 1);
          assert(context.font == &original && context.size == 11.25 && context.marker == 42);
      }
      step = 0;
      CTFontDrawGlyphs(NULL, glyphs, positions, 3, &context);
      CTFontDrawGlyphs(&font, NULL, positions, 3, &context);
      CTFontDrawGlyphs(&font, glyphs, NULL, 3, &context);
      CTFontDrawGlyphs(&font, glyphs, positions, 0, &context);
      CTFontDrawGlyphs(&font, glyphs, positions, 3, NULL);
      assert(step == 0 && copies == 3 && draws == 3);
      fail_copy = 1;
      CTFontDrawGlyphs(&font, glyphs, positions, 3, &context);
      assert(step == 0 && copies == 4 && draws == 3 && font.references == 1);
      assert(context.font == &original && context.size == 11.25 && context.marker == 42);
      puts("CTFontDrawGlyphs dispatch, ownership and state tests passed");
  }
C
Dir.mktmpdir('font-draw-glyphs') do |dir|
  input = File.join(dir, 'probe.c')
  output = File.join(dir, 'probe')
  File.write(input, harness)
  command = [ENV.fetch('CC', 'clang'), '-std=c11', '-Wall', '-Wextra', '-O2',
             '-fsanitize=address,undefined', input, '-o', output]
  log, status = Open3.capture2e(*command)
  abort log unless status.success?
  log, status = Open3.capture2e(output)
  puts log
  abort 'probe failed' unless status.success?
end
