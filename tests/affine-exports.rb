# Host shared-library probe of actual wrappers and header helpers. Geometry
# layout adapters use double, as on supported 64-bit targets; not a Darling ABI test.
require 'tmpdir'
require 'open3'
root=ARGV[0] || File.expand_path('..',__dir__)
header=File.read(File.join(root,'CoreGraphics/include/CoreGraphics/CGAffineTransform.h'))
source=File.read(File.join(root,'CoreGraphics/CGAffineTransform.m'))
helpers=header.scan(/static inline (?:CGPoint|CGSize) __CG.*?^\}/m).join("\n")
wrappers=source.scan(/COREGRAPHICS_EXPORT (?:CGPoint|CGSize) CG.*?^\}/m).join("\n")
abort 'helpers missing' if helpers.empty?
types=<<~'C'
  typedef struct { double x,y; } CGPoint;
  typedef struct { double width,height; } CGSize;
  typedef struct { double a,b,c,d,tx,ty; } CGAffineTransform;
  #define COREGRAPHICS_EXPORT __attribute__((visibility("default")))
C
test=types+<<~'C'
  #include <assert.h>
  #include <dlfcn.h>
  #include <stdio.h>
  typedef CGPoint (*PointFn)(CGPoint,CGAffineTransform);
  typedef CGSize (*SizeFn)(CGSize,CGAffineTransform);
  int main(int argc,char **argv) {
    void *lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL); assert(lib);
    PointFn point=(PointFn)dlsym(lib,"CGPointApplyAffineTransform");
    SizeFn size=(SizeFn)dlsym(lib,"CGSizeApplyAffineTransform");
    assert(point && size);
    const CGAffineTransform ts[]={
      {1,0,0,1,0,0}, {1,0,0,1,13,-7}, {0,1,-1,0,0,0},
      {-2,0,0,3,0,0}, {1,2,3,1,-4,8}, {0,0,0,0,6,9}};
    // Independent expected results for input (2,5): identity, translation,
    // quarter rotation, reflection/scale, shear and singular transformation.
    const double p[][2]={{2,5},{15,-2},{-5,2},{-4,15},{13,17},{6,9}};
    const double s[][2]={{2,5},{2,5},{-5,2},{-4,15},{17,9},{0,0}};
    for(unsigned i=0;i<6;i++) {
      CGPoint a=point((CGPoint){2,5},ts[i]);
      CGSize b=size((CGSize){2,5},ts[i]);
      assert(a.x==p[i][0] && a.y==p[i][1]);
      assert(b.width==s[i][0] && b.height==s[i][1]);
    }
    assert(dlclose(lib)==0);
    puts("PASS: dynamic canonical lookup and point/size arithmetic across six transforms");
  }
C
Dir.mktmpdir('affine-exports') do |dir|
  libsrc=File.join(dir,'lib.c'); testsrc=File.join(dir,'test.c')
  lib=File.join(dir,'libprobe.so'); exe=File.join(dir,'probe')
  File.write(libsrc,types+helpers+"\n"+wrappers); File.write(testsrc,test)
  abort 'library compile failed' unless system('clang','-shared','-fPIC','-fvisibility=hidden',libsrc,'-o',lib)
  abort 'test compile failed' unless system('clang',testsrc,'-ldl','-o',exe)
  Process.setrlimit(Process::RLIMIT_CORE,0)
  abort 'probe failed' unless system(exe,lib)
end
