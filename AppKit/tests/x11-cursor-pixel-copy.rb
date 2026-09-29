# Tests the actual merged pixel-copy loop against native Xcursor pixel layout.
require 'tmpdir'
source=File.read(File.join(ARGV.fetch(0),'AppKit/X11.backend/X11Cursor.m'))
loop_source=source[/    for \(size_t row = 0; row < height;.*?sizeof\(XcursorPixel\)\);/m] or abort 'missing loop'
program=<<~C
  #include <X11/Xcursor/Xcursor.h>
  #include <stdint.h>
  #include <string.h>
  #include <assert.h>
  #include <stdio.h>
  int main(void) {
    _Static_assert(sizeof(XcursorPixel)==4,"pixel size");
    const size_t width=3,height=2,bytesPerRow=16;
    XcursorPixel input[8]={1,2,3,99,4,5,6,99};
    XcursorPixel output[6]={0};
    XcursorImage image={0}; image.pixels=output;
    XcursorImage *ximage=&image;
    const uint8_t *rowBytes=(const uint8_t*)input;
    #{loop_source}
    for(unsigned i=0;i<6;i++) assert(output[i]==i+1);
    puts("PASS merged cursor copy: typed pixel offsets and padded source rows");
  }
C
Dir.mktmpdir('merged-cursor-copy-') do |dir|
  input=File.join(dir,'probe.c'); output=File.join(dir,'probe')
  File.write(input,program)
  abort 'compile failed' unless system('clang','-O2','-Wall','-Werror',
    '-fsanitize=address,undefined',input,'-o',output)
  abort 'test failed' unless system(output)
end
