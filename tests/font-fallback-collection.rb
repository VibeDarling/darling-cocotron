# Real Fontconfig/FreeType integration with actual CoreText caller and factory.
# Font/CF adapters stand in for the Darling object model; no rendering is tested.
# Usage: ruby tests/font-fallback-collection.rb GNUSTEP_ROOT FONT0 FONT1
require 'tmpdir'
require 'open3'
require 'shellwords'
sdk, font0, font1 = ARGV
abort 'provide GNUSTEP_ROOT FONT0 FONT1' unless font1
candidate = File.expand_path('../Onyx2D/O2Font_freetype.m', __dir__)
source = File.read(candidate)
method = source[/O2FontRef O2FontCreateWithCodePointCoverage\(.*?^\}/m]
abort 'selector missing' unless method
coretext = File.read(File.expand_path('../CoreText/CTFont.m', __dir__))
caller = coretext[/CTFontRef CTFontCreateForString\(.*?(?=\nCTFontDescriptorRef)/m]
factory = coretext[/static Class fontClass;.*?(?=\nstatic CGFontRef graphicsFont)/m]
abort 'caller/factory missing' unless caller && factory
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <fontconfig/fontconfig.h>
  #include <ft2build.h>
  #include FT_FREETYPE_H
  #include <assert.h>
  #include <stdint.h>
  #include <pthread.h>
  typedef id O2FontRef;
  static int liveGraphicsFonts;
  static FcConfig *config;
  static FT_Library library;
  static FcConfig *O2FontSharedFontConfig(void) { return config; }
  static FT_Library O2FontSharedFreeTypeLibrary(void) { return library; }
  @interface O2Font_freetype : NSObject { FT_Face _face; }
  - (id)initWithFace:(FT_Face)face;
  - (FT_Face)face;
  @end
  @implementation O2Font_freetype
  - (id)initWithFace:(FT_Face)face { if ((self = [super init])) { _face = face; liveGraphicsFonts++; } return self; }
  - (FT_Face)face { return _face; }
  - (void)dealloc { liveGraphicsFonts--; FT_Done_Face(_face); [super dealloc]; }
  @end
  ACTUAL_SELECTOR
  #ifdef CANDIDATE
  typedef NSInteger CFIndex;
  typedef unichar UniChar;
  typedef NSString *CFStringRef;
  typedef id CTFontRef, CGFontRef, CTFontDescriptorRef;
  typedef struct { CFIndex location, length; } CFRange;
  static CFRange CFRangeMake(CFIndex a, CFIndex b) { return (CFRange){a,b}; }
  static CFIndex CFStringGetLength(CFStringRef s) { return [s length]; }
  static void CFStringGetCharacters(CFStringRef s, CFRange r, UniChar *out) {
      [s getCharacters:out range:NSMakeRange(r.location,r.length)];
  }
  static id CFRetain(id o) { return [o retain]; }
  static void CFRelease(id o) { [o release]; }
  @interface KTFont : NSObject { @public O2Font_freetype *graphics; CGFloat size; NSArray *cascade; }
  - (id)initWithFont:(id)font size:(CGFloat)pointSize;
  @end
  @implementation KTFont
  - (id)initWithFont:(id)font size:(CGFloat)pointSize {
      if ((self = [super init])) { graphics = [font retain]; size = pointSize; }
      return self;
  }
  - (void)dealloc { [cascade release]; [graphics release]; [super dealloc]; }
  @end
  @interface RegisteredFont : KTFont @end
  @implementation RegisteredFont @end
  // GNU libobjc lacks associated objects. These adapters model copy ownership,
  // not the actual Darling runtime's association implementation.
  #define OBJC_ASSOCIATION_COPY 1
  static id objc_getAssociatedObject(id object, const void *key) { return ((KTFont *)object)->cascade; }
  static void objc_setAssociatedObject(id object, const void *key, id value, int policy) {
      NSArray *copy = [value copy]; [((KTFont *)object)->cascade release]; ((KTFont *)object)->cascade = copy;
  }
  ACTUAL_FACTORY
  static FT_Face faceForFont(CTFontRef f) { return [((KTFont *)f)->graphics face]; }
  static CGFloat CTFontGetSize(CTFontRef f) { return ((KTFont *)f)->size; }
  static void O2FontRelease(O2FontRef f) { [f release]; }
  static CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size, void *matrix) {
      return createFont([descriptor objectForKey:@"graphics"], size);
  }
  CTFontRef CTFontCreateForStringWithLanguage(CTFontRef, CFStringRef, CFRange, CFStringRef);
  ACTUAL_CALLER
  #define SELECT(cp, count) O2FontCreateWithCodePointCoverage(cp, count, first, "en")
  #else
  #define SELECT(cp, count) O2FontCreateWithCodePointCoverage(cp, count)
  #endif
  int main(int argc, char **argv) {
      assert(argc == 2);
      @autoreleasepool {
          assert(FT_Init_FreeType(&library) == 0);
          FT_Face first, second;
          assert(FT_New_Face(library, argv[1], 0, &first) == 0);
          assert(FT_New_Face(library, argv[1], 1, &second) == 0);
          assert(first->num_faces == 2 && second->num_faces == 2);
          assert(FT_Select_Charmap(first, FT_ENCODING_UNICODE) == 0);
          assert(FT_Select_Charmap(second, FT_ENCODING_UNICODE) == 0);
          uint32_t cp = 0;
          for (uint32_t candidate = 1; candidate <= 0x10FFFF; candidate++) {
              if (!FT_Get_Char_Index(first, candidate) && FT_Get_Char_Index(second, candidate)) {
                  cp = candidate; break;
              }
          }
          assert(cp && "FONT1 must cover a character not in FONT0");
          config = FcConfigCreate(); assert(config);
          assert(FcConfigAppFontAddFile(config, (const FcChar8 *)argv[1]));
          FcPattern *pattern = FcPatternCreate();
          FcCharSet *characters = FcCharSetCreate();
          assert(FcCharSetAddChar(characters, cp));
          assert(FcPatternAddCharSet(pattern, FC_CHARSET, characters));
          FcCharSetDestroy(characters);
          FcConfigSubstitute(config, pattern, FcMatchPattern);
          FcDefaultSubstitute(pattern);
          FcResult result;
          FcPattern *match = FcFontMatch(config, pattern, &result); assert(match);
          int index = -1;
          assert(FcPatternGetInteger(match, FC_INDEX, 0, &index) == FcResultMatch);
          assert(index == 1);
          FcPatternDestroy(match); FcPatternDestroy(pattern);
          O2FontRef font = SELECT(&cp, 1);
  #ifdef CANDIDATE
          assert(font != nil && [font face]->face_index == 1);
          assert(FT_Get_Char_Index([font face], cp) != 0);
          [font release];
          uint32_t invalid = 0xD800;
          assert(SELECT(&invalid, 1) == nil);
          invalid = 0x110000;
          assert(SELECT(&invalid, 1) == nil);
          assert(SELECT(NULL, 1) == nil);
          assert(SELECT(&cp, 0) == nil);
          uint32_t absent = 0;
          for (uint32_t c = 1; c <= 0x10FFFF; c++) {
              if (c >= 0xD800 && c <= 0xDFFF) continue;
              if (!FT_Get_Char_Index(first, c) && !FT_Get_Char_Index(second, c)) { absent = c; break; }
          }
          assert(absent && SELECT(&absent, 1) == nil);
          uint32_t shared = 'A';
          font = O2FontCreateWithCodePointCoverage(&shared, 1, first, "en");
          assert(font && [font face]->face_index == 0);
          [font release];
          font = O2FontCreateWithCodePointCoverage(&shared, 1, second, "en");
          assert(font && [font face]->face_index == 1);
          [font release];
          printf("PASS: candidate opens selected face 1 for U+%04X; uncovered/invalid inputs rejected\n", cp);
          assert(liveGraphicsFonts == 0);
          _CTFontSetConcreteClass([RegisteredFont class]);
          assert(FT_Reference_Face(first) == 0);
          O2Font_freetype *baseGraphics = [[O2Font_freetype alloc] initWithFace:first];
          KTFont *base = createFont(baseGraphics, 17.5);
          [baseGraphics release];
          assert([base class] == [RegisteredFont class] && liveGraphicsFonts == 1);
          NSUInteger refs = [base retainCount];
          id same = CTFontCreateForString(base, @"A", CFRangeMake(0,1));
          assert(same == base && [base retainCount] == refs + 1);
          [same release];
          UniChar units[2]; CFIndex length;
          if (cp <= 0xFFFF) { units[0] = cp; length = 1; }
          else { units[0] = 0xD800 + ((cp-0x10000)>>10); units[1] = 0xDC00 + ((cp-0x10000)&1023); length = 2; }
          NSString *text = [NSString stringWithCharacters:units length:length];
          KTFont *fallback = CTFontCreateForStringWithLanguage(base,text,CFRangeMake(0,length),@"en");
          assert(fallback != nil && fallback != base && [fallback class] == [RegisteredFont class]);
          assert(fallback->size == 17.5 && faceForFont(fallback)->face_index == 1);
          assert(FT_Get_Char_Index(faceForFont(fallback),cp) != 0 && liveGraphicsFonts == 2);
          [fallback release];
          assert(liveGraphicsFonts == 1 && [base retainCount] == refs);
          [base release];
          assert(liveGraphicsFonts == 0);
          puts("PASS: actual CoreText caller, registered factory and real selector preserve identity/size/class and release owned faces");
  #else
          assert(font == nil);
          printf("CONFIRMED: Fontconfig selects face 1 for U+%04X, but private selector opens face 0 and returns nil\n", cp);
  #endif
          FcConfigDestroy(config); FT_Done_Face(first); FT_Done_Face(second);
          FT_Done_FreeType(library);
      }
  }
OBJC
program = program.sub('ACTUAL_SELECTOR') { method }
program = program.sub('ACTUAL_FACTORY') { factory }.sub('ACTUAL_CALLER') { caller }
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'GCC headers unavailable' unless status.success?
flags, status = Open3.capture2e('pkg-config', '--cflags', '--libs', 'fontconfig', 'freetype2')
abort flags unless status.success?
Dir.mktmpdir('coretext-fallback-face-index') do |dir|
  # TTC v1 container with independent tables. Relocate each sfnt table offset
  # to its absolute position in the collection; leave the font tables intact.
  ttc = 'ttcf'.b + [0x00010000, 2, 0, 0].pack('N4')
  [font0, font1].each_with_index do |path, index|
    bytes = File.binread(path)
    abort 'expected a TrueType sfnt input' unless bytes[0,4] == [0x00010000].pack('N')
    ttc << "\0" until ttc.bytesize % 4 == 0
    offset = ttc.bytesize
    ttc[12 + index * 4, 4] = [offset].pack('N')
    tables = bytes[4,2].unpack1('n')
    tables.times do |table|
      location = 12 + table * 16 + 8
      bytes[location,4] = [bytes[location,4].unpack1('N') + offset].pack('N')
    end
    ttc << bytes
  end
  fixture = File.join(dir, 'fixture.ttc'); File.binwrite(fixture, ttc)
  input = File.join(dir, 'probe.m'); output = File.join(dir, 'probe')
  File.write(input, program)
  abort 'compile failed' unless system('clang', '-O2', '-fobjc-runtime=gcc',
    *(candidate ? ['-DCANDIDATE'] : []),
    '-fconstant-string-class=NSConstantString', "-I#{sdk}/usr/include/GNUstep", "-I#{gcc.strip}",
    input, *Shellwords.split(flags), "-L#{sdk}/usr/lib", "-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base', '-lobjc', '-o', output)
  abort 'probe failed' unless system(output, fixture, rlimit_core: 0)
end

