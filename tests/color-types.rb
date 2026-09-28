# Actual type methods with controlled color storage, not full AppKit factories.
# Usage: ruby tests/color-types.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk, root = ARGV
root ||= File.expand_path('..',__dir__)
header = File.read(File.join(root,'AppKit/include/AppKit/NSColor.h'))
enum = header[/typedef NS_ENUM\(NSInteger, NSColorType\).*?\};/m] or abort 'missing enum'
methods = %w[NSColor NSColor_CGColor NSColor_catalog NSColor_dynamic].map do |name|
  source=File.read(File.join(root,"AppKit/NSColor.subproj/#{name}.m"))
  source[/^- \(NSColorType\) type.*?^\}/m] or abort "missing #{name} type"
end
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  ENUM
  static NSString *NSPatternColorSpace=@"NSPatternColorSpace";
  @interface Base : NSObject @end
  @implementation Base
  BASE
  @end
  @interface CG : Base { @public NSString *_colorSpaceName; } @end
  @implementation CG
  CGMETHOD
  @end
  @interface Catalog : Base @end
  @implementation Catalog
  CATALOG
  @end
  @interface Dynamic : Base @end
  @implementation Dynamic
  DYNAMIC
  - (id)_resolvedColor { abort(); }
  @end
  int main(void) {
    @autoreleasepool {
      Base *base=[Base new]; assert([base type]==NSColorTypeComponentBased); [base release];
      CG *cg=[CG new];
      for(NSString *name in @[@"NSDeviceRGBColorSpace",@"NSDeviceWhiteColorSpace",@"NSDeviceCMYKColorSpace",@"NSCustomColorSpace"]) {
        cg->_colorSpaceName=name; assert([cg type]==NSColorTypeComponentBased);
      }
      cg->_colorSpaceName=[NSMutableString stringWithString:NSPatternColorSpace];
      assert([cg type]==NSColorTypePattern);
      cg->_colorSpaceName=nil; assert([cg type]==NSColorTypeComponentBased); [cg release];
      Catalog *catalog=[Catalog new]; assert([catalog type]==NSColorTypeCatalog); [catalog release];
      Dynamic *dynamic=[Dynamic new];
      assert([dynamic type]==NSColorTypeCatalog && [dynamic type]!=NSColorTypeComponentBased);
      assert([dynamic type]==NSColorTypeCatalog); [dynamic release];
      puts("PASS: component/pattern/catalog/dynamic classification without resolution");
    }
  }
OBJC
%w[BASE CGMETHOD CATALOG DYNAMIC].zip(methods).each { |key,value| program.sub!(key) { value } }
program.sub!('ENUM') { enum }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('color-types') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,rlimit_core:0)
end
