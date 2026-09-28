# Native test of actual renderer helper and extracted Onyx2D CMYK case.
# CoreGraphics accessors and GL output are test doubles; no pixel rendering.
require 'tmpdir'
root = ARGV[0] || File.expand_path('..', __dir__)
renderer = File.read(File.join(root, 'QuartzCore/CARenderer.m'))
helper = renderer[/^static BOOL setPremultipliedColor\(.*?^\}/m]
onyx = File.read(File.join(root, 'Onyx2D/O2Color.m'))
conversion = onyx[/    case kO2ColorSpaceModelCMYK:;.*?        return 1;/m]
abort 'source extraction failed' unless helper && conversion
program = <<~C
  #include <assert.h>
  #include <math.h>
  #include <stddef.h>
  #include <stdio.h>
  typedef double CGFloat, O2Float;
  typedef int BOOL, CGColorSpaceModel, O2ColorSpaceRef;
  enum { NO, YES, kCGColorSpaceModelRGB, kCGColorSpaceModelMonochrome, kCGColorSpaceModelCMYK };
  #define kO2ColorSpaceModelCMYK kCGColorSpaceModelCMYK
  struct Color { int model; size_t count; const double *components; };
  typedef struct Color *CGColorRef;
  static size_t CGColorGetNumberOfComponents(CGColorRef c) { return c->count; }
  static const double *CGColorGetComponents(CGColorRef c) { return c->components; }
  static int CGColorGetColorSpace(CGColorRef c) { return c->model; }
  static int CGColorSpaceGetModel(int s) { return s; }
  static float captured[4];
  static int calls, conversions;
  static void glColor4f(float r, float g, float b, float a) {
      ++calls; captured[0]=r; captured[1]=g; captured[2]=b; captured[3]=a;
  }
  static int O2ColorConvertComponentsToDeviceRGB(int space, const O2Float *components, O2Float *rgbComponents) {
      ++conversions;
      switch (space) { #{conversion} default: return 0; }
  }
  #{helper}
  static void near(double actual, double expected) { assert(fabs(actual-expected)<1e-6); }
  int main(void) {
      for (int k=0; k<=4; ++k) for (int c=0; c<=4; ++c) {
          double components[]={c/4.0, .25, .75, k/4.0, .5};
          struct Color color={kCGColorSpaceModelCMYK,5,components};
          calls=conversions=0;
          assert(setPremultipliedColor(&color,.5));
          assert(calls==1 && conversions==1);
          near(captured[0], (1-c/4.0)*(1-k/4.0)*.25);
          near(captured[1], .75*(1-k/4.0)*.25);
          near(captured[2], .25*(1-k/4.0)*.25); near(captured[3], .25);
      }
      double components[]={.2,.4,.6,.5,1};
      struct Color color={kCGColorSpaceModelRGB,4,components};
      assert(setPremultipliedColor(&color,.5)); near(captured[0],.05); near(captured[3],.25);
      color.count=3;
      assert(setPremultipliedColor(&color,.5)); near(captured[0],.1); near(captured[3],.5);
      color.model=kCGColorSpaceModelMonochrome; color.count=2;
      assert(setPremultipliedColor(&color,.5)); near(captured[0],.04); near(captured[3],.2);
      color.model=kCGColorSpaceModelCMYK; color.count=4; calls=conversions=0;
      assert(!setPremultipliedColor(&color,1)); assert(calls==0 && conversions==0);
      color.count=5;
      assert(!setPremultipliedColor(&color,0)); assert(calls==0);
      color.components=NULL;
      assert(!setPremultipliedColor(&color,1));
      assert(!setPremultipliedColor(NULL,1));
      color.components=components; color.model=99;
      assert(!setPremultipliedColor(&color,1));
      puts("PASS: CMYK matrix, alpha/opacity, RGB/gray and rejected inputs");
  }
C
Dir.mktmpdir('renderer-cmyk') do |dir|
  input = File.join(dir, 'probe.c'); output = File.join(dir, 'probe')
  File.write(input, program)
  abort 'compile failed' unless system('clang', '-O2', '-fsanitize=address,undefined', input, '-lm', '-o', output)
  abort 'test failed' unless system(output, rlimit_core: 0)
end
