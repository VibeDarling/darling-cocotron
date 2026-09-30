# Actual context timer methods with real GNUstep scheduling and a controlled renderer.
# Usage: ruby cocotron-render-redirty.rb GNUSTEP_ROOT CALayerContext.m
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
path=ARGV[1] || File.expand_path('../QuartzCore/CALayerContext.m',__dir__)
source=File.read(path)
names=['timer: (NSTimer *) timer','startTimerIfNeeded','renderOnce: (NSTimer *) timer','scheduleRenderIfNeeded','invalidate']
methods=names.filter_map{|n| source[/^- \(void\) #{Regexp.escape(n)} \{.*?^\}/m]}.join("\n")
private_scheduler=methods.include?('scheduleRenderIfNeeded')
predicate=source[/^static BOOL layerTreeNeedsAnotherFrame\(.*?^\}/m] or abort 'missing frame predicate'
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static unsigned frames, requestedFrames, animationFrames, metalFrames;
  static BOOL cancelFirst;
  @interface CALayer : NSObject
  - (NSArray *)animationKeys;
  - (NSArray *)sublayers;
  @end
  @implementation CALayer
  - (NSArray *)animationKeys { return frames < animationFrames ? @[@1] : @[]; }
  - (NSArray *)sublayers { return @[]; }
  @end
  @interface CAMetalLayerInternal : CALayer
  - (BOOL)hasQueuedDrawables;
  @end
  @implementation CAMetalLayerInternal
  - (BOOL)hasQueuedDrawables { return frames < metalFrames; }
  @end
  ACTUAL_PREDICATE
  static double CACurrentMediaTime(void) { return 0; }
  @interface Renderer : NSObject @end
  @implementation Renderer
  - (void)beginFrameAtTime:(double)t timeStamp:(void *)s {}
  - (void)endFrame {}
  @end
  @interface Context : NSObject {
    NSTimer *_timer, *_renderTimer; Renderer *_renderer; id _layer; BOOL _renderRequested;
  }
  - (void)timer:(NSTimer *)timer;
  - (void)startTimerIfNeeded;
  - (void)invalidate;
  @end
  @implementation Context
  ACTUAL_METHODS
  - (id)init { if((self=[super init])) { _renderer=[Renderer new]; _layer=[CAMetalLayerInternal new]; } return self; }
  - (void)render {
    ++frames;
    if(cancelFirst && frames==1) [self invalidate];
    // Simulate one delegate invalidation after its current frame began.
    if(frames < requestedFrames) {
      for(unsigned i=0;i<10;++i) [self SCHEDULE];
    }
  }
  - (void)flush {}
  - (void)stop {
    [_timer invalidate]; [_timer release]; _timer=nil;
    [_renderTimer invalidate]; [_renderTimer release]; _renderTimer=nil;
  }
  - (void)dealloc { [self stop]; [_renderer release]; [_layer release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      for(requestedFrames=1; requestedFrames<=3; ++requestedFrames) {
      frames=0;
      Context *context=[Context new];
      [context SCHEDULE];
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
      [context stop]; [context release];
      fprintf(stderr,"observed frames=%u\n",frames);
      assert(frames==requestedFrames && "in-frame requests must coalesce without being lost");
      }
      frames=0; requestedFrames=1; animationFrames=3;
      Context *animated=[Context new]; [animated startTimerIfNeeded];
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
      [animated stop]; [animated release];
      assert(frames==3);
      frames=0; animationFrames=0; metalFrames=3;
      Context *metal=[Context new]; [metal startTimerIfNeeded];
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
      [metal stop]; [metal release]; assert(frames==3); metalFrames=0;
      // Enable only when testing composition with real cancellation (#266).
      COMPOSITION_TEST
      puts("PASS: one to three frames, coalesced requests, idle stopping and animation continuation");
    }
  }
OBJC
program=program.sub('ACTUAL_METHODS'){methods}.gsub('SCHEDULE',private_scheduler ? 'scheduleRenderIfNeeded' : 'startTimerIfNeeded')
program=program.sub('ACTUAL_PREDICATE'){predicate}
composition = source[/^- \(void\) invalidate \{.*?^\}/m].to_s.include?('[_timer invalidate]')
program=program.sub('COMPOSITION_TEST', composition ? <<~'OBJC' : '')
  animationFrames=0; cancelFirst=YES;
  for(requestedFrames=1; requestedFrames<=2; ++requestedFrames) {
    frames=0;
    Context *c=[Context new]; [c startTimerIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    [c stop]; [c release];
    assert(frames==requestedFrames);
  }
  puts("PASS: actual cancellation during render, with and without a replacement request");
OBJC
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('render-redirty') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'redirty regression failed' unless system(output,rlimit_core:0)
end
