# Linux host test of the actual method with GNUstep Foundation and mocked UTType.
# Does not test Darling AppKit loading or the real UniformTypeIdentifiers registry.
# Usage: ruby run-document-extension-method.rb GNUSTEP_ROOT [NSDocumentController.m]
require 'tmpdir'
require 'open3'
sdk = File.expand_path(ARGV.fetch(0))
source = File.read(ARGV[1] || File.expand_path('../AppKit/NSDocumentController.m', __dir__))
method = source[/^- \(NSString \*\) typeFromFileExtension:.*?^\}/m]
abort 'method not found' unless method
url_method = source[/^- \(NSString \*\) typeForContentsOfURL:.*?^\}/m]
abort 'URL method not found' unless url_method
fixture = File.read(File.join(__dir__, 'appkit-document-uti-extensions.m'))
fixture = fixture.lines.reject { |line| line.start_with?('#import') }.join
prelude = <<~'OBJC'
  #import <Foundation/Foundation.h>
  @interface UTType : NSObject
  + (instancetype)typeWithFilenameExtension:(NSString *)extension;
  - (NSString *)identifier;
  @end
  static NSString *resolved;
  #ifndef PROBE_NO_PROVIDER
  @implementation UTType
  #ifndef PROBE_OLD_PROVIDER
  + (instancetype)typeWithFilenameExtension:(NSString *)extension {
      NSString *lower = [extension lowercaseString];
      resolved = ([lower isEqual:@"txt"] || [lower isEqual:@"text"]) ? @"public.plain-text" :
          ([lower isEqual:@"png"] ? @"public.png" : @"dyn.probe-unknown");
      return [[[self alloc] init] autorelease];
  }
  - (NSString *)identifier { return resolved; }
  #endif
  @end
  #endif
  @interface NSDocumentController : NSObject {
  @protected
      NSArray *_fileTypes;
  }
  - (NSString *)typeFromFileExtension:(NSString *)extension;
  - (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)error;
  @end
  @implementation NSDocumentController
  - (void)dealloc { [_fileTypes release]; [super dealloc]; }
OBJC
gcc_include, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'GCC include discovery failed' unless status.success?
Dir.mktmpdir('document-extensions') do |dir|
  input = File.join(dir, 'probe.m'); executable = File.join(dir, 'probe')
  File.write(input, prelude + method + "\n" + url_method + "\n@end\n" + fixture)
  variants = { 'available' => [], 'absent' => ['-DPROBE_WITHOUT_PROVIDER', '-DPROBE_NO_PROVIDER'],
               'older API' => ['-DPROBE_WITHOUT_PROVIDER', '-DPROBE_OLD_PROVIDER', '-Wno-incomplete-implementation'] }
  variants.each do |name, flags|
  puts "Provider: #{name}"
  abort 'compile failed' unless system(ENV.fetch('CC', 'clang'), *flags, '-O2', '-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString', "-I#{sdk}/usr/include/GNUstep",
    "-I#{gcc_include.strip}", input, "-L#{sdk}/usr/lib", "-Wl,-rpath,#{sdk}/usr/lib",
    '-lgnustep-base', '-lobjc', '-o', executable)
  abort 'method test failed' unless system(executable, rlimit_core: 0)
  end
end
