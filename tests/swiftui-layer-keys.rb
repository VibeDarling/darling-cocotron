# Host KVC dispatch with actual CALayer accessors and a controlled association
# store. This does not test Darling's runtime association teardown or Foundation.
# Usage: ruby tests/swiftui-layer-keys.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
source=File.read(File.join(root,'QuartzCore/CALayer.m'))
methods=source.scan(/^- \((?:id|void)\) (?:_swiftUI_\w+|set_swiftUI_\w+: \(id\) value) \{.*?^\}/m).join("\n")
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static char swiftUIDisplayListIDAssociationKey, swiftUIViewTestPropertiesAssociationKey;
  enum { OBJC_ASSOCIATION_RETAIN_NONATOMIC=1 };
  @interface Probe : NSObject { @public NSMutableDictionary *associations; }
  @end
  static id objc_getAssociatedObject(Probe *object,const void *key) {
    return [object->associations objectForKey:[NSValue valueWithPointer:key]];
  }
  static void objc_setAssociatedObject(Probe *object,const void *key,id value,int policy) {
    assert(policy==OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(!object->associations) object->associations=[NSMutableDictionary new];
    id k=[NSValue valueWithPointer:key];
    if(value) [object->associations setObject:value forKey:k];
    else [object->associations removeObjectForKey:k];
  }
  @implementation Probe
  ACTUAL_METHODS
  - (void)dealloc { [associations release]; [super dealloc]; }
  @end
  static unsigned deaths;
  @interface Tracked : NSObject @end
  @implementation Tracked
  - (void)dealloc { ++deaths; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      NSString *display=@"_swiftUI_displayListID", *properties=@"_swiftUI_viewTestProperties";
      Probe *a=[Probe new],*b=[Probe new];
      assert([a valueForKey:display]==nil && [a valueForKey:properties]==nil);
      @autoreleasepool {
        [a setValue:[NSNumber numberWithInteger:-42] forKey:display];
        [a setValue:[NSNumber numberWithUnsignedLongLong:~0ULL] forKey:properties];
      }
      assert([[a valueForKey:display] integerValue]==-42);
      assert([[a valueForKey:properties] unsignedLongLongValue]==~0ULL);
      assert([b valueForKey:display]==nil && [b valueForKey:properties]==nil);
      id retained=[a valueForKey:display];
      [a setValue:retained forKey:display];
      assert([a valueForKey:display]==retained);
      [a setValue:nil forKey:display]; assert([a valueForKey:display]==nil);
      assert([[a valueForKey:properties] unsignedLongLongValue]==~0ULL);
      Tracked *value=[Tracked new]; [a setValue:value forKey:display]; [value release];
      assert(deaths==0); [a setValue:nil forKey:display]; assert(deaths==1);
      value=[Tracked new]; [b setValue:value forKey:properties]; [value release];
      [a release]; assert(deaths==1); [b release]; assert(deaths==2);
      puts("PASS: KVC keys, nil, independent values/layers, numeric boxing and adapter ownership");
    }
  }
OBJC
program=program.sub('ACTUAL_METHODS'){methods}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('layer-keys') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'KVC probe failed' unless system(output,rlimit_core:0)
end
