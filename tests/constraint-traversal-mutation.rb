# Actual constraint traversal with controlled callbacks and a mutable view tree.
# Usage: ruby tests/constraint-traversal-mutation.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
sdk,root=ARGV
root ||= File.expand_path('..',__dir__)
source=File.read(File.join(root,'AppKit/NSView.m'))
method=source[/^- \(void\) updateConstraintsForSubtreeIfNeeded \{.*?^\}/m]
abort 'missing traversal' unless method
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  static unsigned deaths;
  @interface NSView : NSObject {
  @public NSMutableArray *_subviews; BOOL _needsUpdateConstraints;
    NSView *parent; BOOL removesSelf; unsigned updates;
    NSView *removeTarget, *destination; BOOL raises;
  }
  - (void)updateConstraintsForSubtreeIfNeeded;
  @end
  @implementation NSView
  ACTUAL_METHOD
  - (id)init { if((self=[super init])) _subviews=[NSMutableArray new]; return self; }
  - (void)updateConstraints {
    ++updates;
    if(removesSelf) { [parent->_subviews removeObjectIdenticalTo:self]; parent=nil; }
    if(removeTarget) {
      [removeTarget retain];
      [removeTarget->parent->_subviews removeObjectIdenticalTo:removeTarget];
      removeTarget->parent=destination;
      if(destination) [destination->_subviews addObject:removeTarget];
      [removeTarget release];
    }
    if(raises) [NSException raise:@"ProbeCallback" format:@"controlled callback failure"];
  }
  - (NSView *)superview { return parent; }
  - (void)dealloc { ++deaths; [_subviews release]; [super dealloc]; }
  @end
  int main(void) {
    @autoreleasepool {
      NSView *root=[NSView new],*a=[NSView new],*b=[NSView new];
      [root->_subviews addObject:a]; [root->_subviews addObject:b];
      a->parent=root; b->parent=root;
      a->_needsUpdateConstraints=YES; b->_needsUpdateConstraints=YES;
      // Clean parent must still visit dirty descendants.
      [root updateConstraintsForSubtreeIfNeeded];
      assert(root->updates==0 && a->updates==1 && b->updates==1);
      [root updateConstraintsForSubtreeIfNeeded];
      assert(a->updates==1 && b->updates==1);
      a->_needsUpdateConstraints=YES; b->_needsUpdateConstraints=YES;
      a->removesSelf=YES; BOOL threw=NO;
      @try { [root updateConstraintsForSubtreeIfNeeded]; }
      @catch(NSException *exception) {
        threw=YES; fprintf(stderr,"traversal exception: %s\n",[[exception reason] UTF8String]);
      }
      printf("updates after removal: first=%u second=%u\n",a->updates,b->updates);
      [root release]; [a release]; [b release];
      if(threw) return 1;
      for(unsigned mode=0; mode<3; ++mode) {
        unsigned before=deaths;
        root=[NSView new]; a=[NSView new]; b=[NSView new];
        NSView *other=[NSView new];
        [root->_subviews addObject:a]; [root->_subviews addObject:b];
        a->parent=root; b->parent=root;
        a->_needsUpdateConstraints=YES; b->_needsUpdateConstraints=YES;
        a->removeTarget=b;
        if(mode==1) a->destination=other;
        a->raises=mode==2;
        threw=NO;
        @try { [root updateConstraintsForSubtreeIfNeeded]; }
        @catch(NSException *exception) {
          assert([[exception name] isEqualToString:@"ProbeCallback"]);
          threw=YES;
        }
        assert(threw==(mode==2));
        assert(b->updates==0 && b->_needsUpdateConstraints);
        if(mode==1) { [other updateConstraintsForSubtreeIfNeeded]; assert(b->updates==1); }
        [root release]; [a release]; [b release]; [other release];
        // Includes snapshot release on an exception, without retainCount assumptions.
        assert(deaths==before+4);
      }
      puts("PASS: self/sibling removal, reparenting, deferred dirty work and exception snapshot cleanup");
    }
  }
OBJC
program=program.sub('ACTUAL_METHOD'){method}
gcc,status=Open3.capture2('gcc','-print-file-name=include')
abort 'missing headers' unless status.success?
Dir.mktmpdir('constraint-traversal') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-O1','-fobjc-runtime=gcc','-fobjc-exceptions','-fexceptions',
    '-fconstant-string-class=NSConstantString',"-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",
    input,"-L#{sdk}/usr/lib","-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  exit(system(output,rlimit_core:0) ? 0 : 1)
end
