# Execute the actual CoreText fallback entry points with real FreeType coverage
# and controlled substitute selection/font construction. Not a framework test.
# Usage: ruby tests/font-fallback-caller.rb GNUSTEP_ROOT FONT0 FONT1
require 'tmpdir'
require 'open3'
require 'shellwords'
sdk, font0, font1 = ARGV
abort 'provide GNUSTEP_ROOT FONT0 FONT1' unless font1
source = File.read(File.expand_path('../CoreText/CTFont.m', __dir__))
methods = source[/CTFontRef CTFontCreateForString\(.*?(?=\nCTFontDescriptorRef)/m]
abort 'methods missing' unless methods
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <ft2build.h>
  #include FT_FREETYPE_H
  #include <assert.h>
  #include <stdint.h>
  typedef NSInteger CFIndex;
  typedef unichar UniChar;
  typedef NSString *CFStringRef;
  typedef struct { CFIndex location, length; } CFRange;
  typedef id CTFontRef, CGFontRef, O2FontRef, CTFontDescriptorRef;
  static CFRange CFRangeMake(CFIndex a, CFIndex b) { return (CFRange){a,b}; }
  static CFIndex CFStringGetLength(CFStringRef s) { return [s length]; }
  static void CFStringGetCharacters(CFStringRef s, CFRange r, UniChar *out) {
      [s getCharacters:out range:NSMakeRange(r.location,r.length)];
  }
  static id CFRetain(id o) { return [o retain]; }
  static void CFRelease(id o) { [o release]; }
  static NSArray *cascade;
  static NSArray *fontCascade(CTFontRef f) { return cascade; }
  @interface RegisteredFont : NSObject { @public FT_Face face; CGFloat size; } @end
  @implementation RegisteredFont @end
  static FT_Face faceForFont(CTFontRef f) { return ((RegisteredFont *)f)->face; }
  static CGFloat CTFontGetSize(CTFontRef f) { return ((RegisteredFont *)f)->size; }
  static RegisteredFont *substitute;
  static int calls, creates, releases;
  static BOOL failSelection;
  static uint32_t expectedScalar;
  static const char *expectedLanguage;
  static FT_Face expectedBase;
  static O2FontRef O2FontCreateWithCodePointCoverage(const uint32_t *cp, size_t n,
          FT_Face base, const char *language) {
      calls++;
      assert(n == 1 && cp[0] == expectedScalar && base == expectedBase);
      assert(expectedLanguage ? language && strcmp(language, expectedLanguage) == 0 : language == NULL);
      return failSelection ? nil : [substitute retain];
  }
  static CTFontRef createFont(CGFontRef graphic, CGFloat size) {
      creates++;
      RegisteredFont *result = [RegisteredFont new];
      result->face = ((RegisteredFont *)graphic)->face; result->size = size;
      return result;
  }
  static void O2FontRelease(O2FontRef f) { releases++; [f release]; }
  static CTFontRef CTFontCreateWithFontDescriptor(CTFontDescriptorRef descriptor, CGFloat size, void *matrix) {
      return createFont([descriptor objectForKey:@"font"], size);
  }
  CTFontRef CTFontCreateForStringWithLanguage(CTFontRef, CFStringRef, CFRange, CFStringRef);
  ACTUAL_METHODS
  int main(int argc, char **argv) {
      assert(argc == 3);
      @autoreleasepool {
          FT_Library library; FT_Face first, second;
          assert(!FT_Init_FreeType(&library));
          assert(!FT_New_Face(library,argv[1],0,&first));
          assert(!FT_New_Face(library,argv[2],0,&second));
          assert(!FT_Select_Charmap(first,FT_ENCODING_UNICODE));
          assert(!FT_Select_Charmap(second,FT_ENCODING_UNICODE));
          RegisteredFont *current = [RegisteredFont new]; current->face = first; current->size = 17.5;
          substitute = [RegisteredFont new]; substitute->face = second;
          NSUInteger references = [current retainCount];
          CTFontRef result = CTFontCreateForString(current,@"A",CFRangeMake(0,1));
          assert(result == current && [current retainCount] == references + 1 && calls == 0);
          [result release];
          result = CTFontCreateForString(current,@"",CFRangeMake(0,0));
          assert(result == current && calls == 0); [result release];
          uint32_t cp;
          for (cp = 1; cp < 0xD800; cp++)
              if (!FT_Get_Char_Index(first,cp) && FT_Get_Char_Index(second,cp)) break;
          assert(cp < 0xD800);
          UniChar character = cp;
          NSString *text = [NSString stringWithCharacters:&character length:1];
          expectedScalar = cp; expectedBase = first; expectedLanguage = "ja";
          result = CTFontCreateForStringWithLanguage(current,text,CFRangeMake(0,1),@"ja");
          assert(result != current && [result class] == [RegisteredFont class]);
          assert(((RegisteredFont *)result)->size == 17.5 && creates == 1 && releases == 1);
          [result release];
          expectedLanguage = NULL; failSelection = YES;
          assert(!CTFontCreateForString(current,text,CFRangeMake(0,1)));
          assert(calls == 2 && creates == 1 && releases == 1);
          const UniChar bad[] = {0xD800,'A'};
          text = [NSString stringWithCharacters:bad length:2];
          assert(!CTFontCreateForString(current,text,CFRangeMake(0,2)));
          assert(!CTFontCreateForString(current,@"A",CFRangeMake(-1,1)));
          assert(!CTFontCreateForString(current,@"A",CFRangeMake(0,2)));
          assert(!CTFontCreateForString(nil,@"A",CFRangeMake(0,1)));
          assert(calls == 2 && [current retainCount] == references);
          cascade = @[@{@"font":current}, @{@"font":substitute}, @{@"font":current}];
          character = cp;
          text = [NSString stringWithCharacters:&character length:1];
          result = CTFontCreateForString(current,text,CFRangeMake(0,1));
          assert(result && ((RegisteredFont *)result)->face == second);
          assert(creates == 3 && calls == 2 && ((RegisteredFont *)result)->size == 17.5);
          [result release];
          cascade = nil;
          [current release]; [substitute release];
          FT_Done_Face(first); FT_Done_Face(second); FT_Done_FreeType(library);
          puts("Fallback caller coverage, retention, factory, size, language and failure tests passed");
      }
  }
OBJC
program = program.sub('ACTUAL_METHODS') { methods }
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'GCC headers unavailable' unless status.success?
flags, status = Open3.capture2e('pkg-config', '--cflags', '--libs', 'freetype2')
abort flags unless status.success?
Dir.mktmpdir('font-fallback-caller') do |dir|
  input = File.join(dir,'probe.m'); output = File.join(dir,'probe')
  File.write(input, program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,*Shellwords.split(flags),"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,font0,font1,rlimit_core:0)
end
