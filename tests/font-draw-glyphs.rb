#!/usr/bin/env ruby
# Executes the actual function against instrumented CG calls, not a rasterizer.
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
  typedef struct { double width, height; } CGSize;
  typedef struct { double a, b, c, d, tx, ty; } CGAffineTransform;
  typedef struct Font { int references; double size; CGAffineTransform matrix; } *CTFontRef, *CGFontRef;
  typedef struct Context { CGFontRef font; double size; CGAffineTransform matrix; } *CGContextRef;
  static size_t draws, expected_count;
  static int copies, releases, fail_copy, matrix_sets, position_sets, font_sets, size_sets;
  static CTFontRef expected_font;
  static const CGGlyph *expected_glyphs;
  static const CGPoint *expected_positions;
  static CGSize CGSizeMake(double w, double h) { return (CGSize){w,h}; }
  static CGFontRef CTFontCopyGraphicsFont(CTFontRef font, void *attributes) {
      assert(font == expected_font && attributes == NULL);
      copies++;
      if (fail_copy) return NULL;
      font->references++;
      return font;
  }
  static double CTFontGetSize(CTFontRef font) { return font->size; }
  static CGAffineTransform CTFontGetMatrix(CTFontRef font) { return font->matrix; }
  static void CGContextSetFont(CGContextRef context, CGFontRef font) {
      font_sets++; context->font = font;
  }
  static void CGContextSetFontSize(CGContextRef context, double size) {
      size_sets++; context->size = size;
  }
  static void CGContextSetTextMatrix(CGContextRef context, CGAffineTransform matrix) {
      matrix_sets++; context->matrix = matrix;
  }
  static void CGContextSetTextPosition(CGContextRef context, double x, double y) {
      position_sets++; context->matrix.tx = x; context->matrix.ty = y;
  }
  static void CGContextShowGlyphsWithAdvances(CGContextRef context,
          const CGGlyph *glyphs, const CGSize *advances, size_t count) {
      assert(draws < expected_count && count == 1);
      assert(matrix_sets == draws + 1 && position_sets == draws + 1);
      assert(font_sets == 1 && size_sets == 1);
      assert(context->font == expected_font && context->size == expected_font->size);
      assert(glyphs == expected_glyphs + draws);
      assert(advances && advances[0].width == 0 && advances[0].height == 0);
      CGAffineTransform m = expected_font->matrix;
      assert(context->matrix.a == m.a && context->matrix.b == m.b);
      assert(context->matrix.c == m.c && context->matrix.d == m.d);
      assert(context->matrix.tx == expected_positions[draws].x);
      assert(context->matrix.ty == expected_positions[draws].y);
      draws++;
  }
  static void CGFontRelease(CGFontRef font) {
      assert(font == expected_font && draws == expected_count);
      font->references--; releases++;
  }
C
harness += method
harness += <<~'C'
  int main(void) {
      struct Font font = {1, 17.5, {1,0,0,1,0,0}}, original = {1,8,{1,0,0,1,0,0}};
      const CGGlyph glyphs[] = {7, 0, 65535};
      const CGPoint positions[] = {{-3, 8}, {7.5, -4}, {22, 1}};
      const CGAffineTransform matrices[] = {
          {1,0,0,1,0,0}, {2,0,0,3,0,0}, {0,1,-1,0,0,0},
          {1,.5,.25,1,0,0}, {0,0,0,0,0,0}
      };
      expected_font = &font; expected_glyphs = glyphs; expected_positions = positions;
      for (size_t m = 0; m < sizeof(matrices)/sizeof(matrices[0]); m++) {
          font.matrix = matrices[m];
          for (size_t count = 1; count <= 3; count++) {
              struct Context context = {&original,11.25,{4,1,2,5,100,200}};
              expected_count = count;
              draws = copies = releases = matrix_sets = position_sets = font_sets = size_sets = 0;
              CTFontDrawGlyphs(&font, glyphs, positions, count, &context);
              assert(draws == count && copies == 1 && releases == 1 && font.references == 1);
              // The selected state is deliberately not restored after drawing.
              assert(context.font == &font && context.size == 17.5);
              assert(context.matrix.a == matrices[m].a && context.matrix.b == matrices[m].b);
              assert(context.matrix.c == matrices[m].c && context.matrix.d == matrices[m].d);
              assert(context.matrix.tx == positions[count-1].x && context.matrix.ty == positions[count-1].y);
          }
      }
      struct Context context = {&original,11.25,{4,1,2,5,100,200}};
      draws = copies = releases = matrix_sets = position_sets = font_sets = size_sets = 0;
      CTFontDrawGlyphs(NULL, glyphs, positions, 3, &context);
      CTFontDrawGlyphs(&font, NULL, positions, 3, &context);
      CTFontDrawGlyphs(&font, glyphs, NULL, 3, &context);
      CTFontDrawGlyphs(&font, glyphs, positions, 0, &context);
      CTFontDrawGlyphs(&font, glyphs, positions, 3, NULL);
      assert(copies == 0 && draws == 0);
      fail_copy = 1;
      CTFontDrawGlyphs(&font, glyphs, positions, 3, &context);
      assert(copies == 1 && draws == 0 && releases == 0 && font.references == 1);
      assert(matrix_sets == 0 && position_sets == 0 && font_sets == 0 && size_sets == 0);
      assert(context.font == &original && context.size == 11.25 && context.matrix.tx == 100);
      puts("CTFontDrawGlyphs user-space positions, state and ownership tests passed");
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
