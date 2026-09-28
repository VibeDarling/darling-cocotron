# Execute actual cascade construction/copy/access methods with GNUstep objects.
# Associated-object storage and graphics-font construction are controlled adapters.
# Usage: ruby tests/font-cascade-roundtrip.rb GNUSTEP_ROOT
require 'tmpdir'
require 'open3'
sdk = ARGV.fetch(0) { abort 'provide GNUSTEP_ROOT' }
source = File.read(File.expand_path('../CoreText/CTFont.m', __dir__))
helpers = source[/static char fontCascadeKey;.*?(?=\nvoid _CTFontSetConcreteClass)/m]
abort 'helpers missing' unless helpers
names = %w[CTFontCreateWithFontDescriptor CTFontCreateCopyWithAttributes CTFontCreateWithGraphicsFont]
methods = names.map { |name| source[/CTFontRef\s+#{name}\(.*?^\}/m] or abort "missing #{name}" }.join("\n")
accessor = source[/CFTypeRef CTFontCopyAttribute\(.*?^\}/m] or abort 'accessor missing'
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  typedef id CTFontRef, CTFontDescriptorRef, CGFontRef, CFTypeRef;
  typedef NSString *CFStringRef;
  typedef struct { double a,b,c,d,tx,ty; } CGAffineTransform;
  #define CFSTR(x) @x
  #define OBJC_ASSOCIATION_COPY 1
  static NSString *kCTFontCascadeListAttribute = @"cascade";
  static NSString *kCTFontNameAttribute = @"name", *kCTFontFamilyNameAttribute = @"family";
  static NSString *kCTFontSizeAttribute = @"size", *kCTFontPostScriptNameAttribute = @"postscript";
  static NSString *kCTFontPostScriptNameKey = @"postscript-key", *kCTFontFullNameKey = @"full-name";
  @interface Font : NSObject { @public id graphic; CGFloat size; NSArray *cascade; } @end
  @implementation Font
  - (void)dealloc { [graphic release]; [cascade release]; [super dealloc]; }
  @end
  static int alive;
  @interface Sentinel : NSObject @end
  @implementation Sentinel
  - (id)init { if ((self = [super init])) alive++; return self; }
  - (void)dealloc { alive--; [super dealloc]; }
  @end
  static id objc_getAssociatedObject(id object, const void *key) { return ((Font *)object)->cascade; }
  static void objc_setAssociatedObject(id object, const void *key, id value, int policy) {
      id copy = [value copy]; [((Font *)object)->cascade release]; ((Font *)object)->cascade = copy;
  }
  static bool CFEqual(id a, id b) { return [a isEqual:b]; }
  static CTFontRef createFont(CGFontRef graphic, CGFloat size) {
      Font *f = [Font new]; f->graphic = [graphic retain]; f->size = size; return f;
  }
  static CGFontRef graphicsFont(CTFontRef f) { return ((Font *)f)->graphic; }
  static CGFloat CTFontGetSize(CTFontRef f) { return ((Font *)f)->size; }
  static CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix) {
      return createFont(name, size > 0 ? size : 12);
  }
  static CFStringRef CTFontCopyName(CTFontRef f, CFStringRef key) { return nil; }
  static CFStringRef CTFontCopyFamilyName(CTFontRef f) { return nil; }
  static CFStringRef CTFontCopyPostScriptName(CTFontRef f) { return nil; }
  ACTUAL_HELPERS
  ACTUAL_METHODS
  ACTUAL_ACCESSOR
  int main(void) {
      @autoreleasepool {
          Sentinel *entry = [Sentinel new];
          NSMutableArray *list = [[NSMutableArray alloc] initWithObjects:entry,nil];
          NSDictionary *descriptor = [[NSDictionary alloc] initWithObjectsAndKeys:
              list,kCTFontCascadeListAttribute,@"fixture",kCTFontNameAttribute,@17.5,kCTFontSizeAttribute,nil];
          Font *font = CTFontCreateWithFontDescriptor(descriptor,0,NULL);
          assert(font->size == 17.5);
          [list removeAllObjects]; [list release]; [descriptor release]; [entry release];
          assert(alive == 1);
          NSArray *copied = CTFontCopyAttribute(font,kCTFontCascadeListAttribute);
          assert([copied count] == 1);
          [copied release];
          Font *inherited = CTFontCreateCopyWithAttributes(font,0,NULL,nil);
          assert(inherited->size == 17.5 && [fontCascade(inherited) count] == 1);
          Font *cleared = CTFontCreateCopyWithAttributes(font,20,NULL,@{kCTFontCascadeListAttribute:@[]});
          assert(cleared->size == 20 && [fontCascade(cleared) count] == 0);
          Font *overridden = CTFontCreateCopyWithAttributes(font,18,NULL,@{kCTFontCascadeListAttribute:@[@"replacement"]});
          assert([[fontCascade(overridden) objectAtIndex:0] isEqual:@"replacement"]);
          Font *graphics = CTFontCreateWithGraphicsFont(@"graphics",21,NULL,@{kCTFontCascadeListAttribute:@[@"graphics-cascade"]});
          assert(graphics->size == 21 && [[fontCascade(graphics) objectAtIndex:0] isEqual:@"graphics-cascade"]);
          Font *plain = CTFontCreateWithFontDescriptor(nil,12,NULL);
          assert(CTFontCopyAttribute(plain,kCTFontCascadeListAttribute) == nil);
          [font release]; assert(alive == 1);
          [inherited release]; assert(alive == 0);
          [cleared release]; [overridden release]; [graphics release]; [plain release];
          puts("Cascade descriptor/graphics construction, lookup, inheritance, override, clearing and adapter ownership passed");
      }
  }
OBJC
program = program.sub('ACTUAL_HELPERS') { helpers }.sub('ACTUAL_METHODS') { methods }.sub('ACTUAL_ACCESSOR') { accessor }
gcc, status = Open3.capture2('gcc','-print-file-name=include')
abort 'GCC headers unavailable' unless status.success?
Dir.mktmpdir('font-cascade-roundtrip') do |dir|
  input = File.join(dir,'probe.m'); output = File.join(dir,'probe')
  File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
