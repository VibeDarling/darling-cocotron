# Runs actual NSDocument methods with a controlled dispatch adapter, not libdispatch.
# Usage: ruby tests/document-continuation.rb GNUSTEP_ROOT [COCOTRON_ROOT]
require 'tmpdir'
require 'open3'
require 'fileutils'
sdk, root = ARGV
abort 'GNUstep SDK root required' unless sdk
root ||= File.expand_path('..', __dir__)
source = File.read(File.join(root, 'AppKit/NSDocument.m'))
methods = %w[unblockUserInteraction continueAsynchronousWorkOnMainThreadUsingBlock].map do |name|
  source[/^- \(void\) #{name}\b.*?^\}/m] or abort "missing #{name}"
end.join("\n")
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <pthread.h>
  typedef void (^Work)(void);
  static int mainQueueToken;
  static Work queued;
  static unsigned submissions;
  static void *dispatch_get_main_queue(void) { return &mainQueueToken; }
  // Deliberately controlled adapter: the caller keeps its block alive until drain.
  // This verifies forwarding/deferral, not libdispatch's block ownership.
  static void dispatch_async(void *queue, Work work) {
    assert(queue == &mainQueueToken && work && !queued);
    queued = work;
    ++submissions;
  }
  static void drain(void) { Work work = queued; queued = nil; work(); }
  @interface Document : NSObject
  @end
  @implementation Document
  ACTUAL_METHODS
  @end
  static void exercise(Document *document) {
    __block unsigned calls = 0;
    unsigned before = submissions;
    Work work = ^{ ++calls; };
    [document unblockUserInteraction];
    [document unblockUserInteraction];
    [document continueAsynchronousWorkOnMainThreadUsingBlock:nil];
    assert(submissions == before && queued == nil);
    [document continueAsynchronousWorkOnMainThreadUsingBlock:work];
    assert(calls == 0 && submissions == before + 1 && queued == work);
    drain();
    assert(calls == 1 && queued == nil);
    [document continueAsynchronousWorkOnMainThreadUsingBlock:work];
    assert(calls == 1 && submissions == before + 2);
    drain();
    assert(calls == 2);
  }
  static void *worker(void *document) {
    @autoreleasepool { exercise((Document *)document); }
    return NULL;
  }
  int main(void) {
    @autoreleasepool {
      Document *document = [Document new];
      exercise(document);
      pthread_t thread;
      assert(pthread_create(&thread, NULL, worker, document) == 0);
      assert(pthread_join(thread, NULL) == 0);
      assert(submissions == 4);
      [document release];
      puts("PASS: main-queue forwarding, non-inline delivery, nil guard, repeated calls, main/worker callers (controlled dispatch)");
    }
  }
OBJC
program.sub!('ACTUAL_METHODS') { methods }
gcc, status = Open3.capture2('gcc', '-print-file-name=include')
abort 'missing compiler headers' unless status.success?
Dir.mktmpdir('document-continuation') do |dir|
  FileUtils.mkdir_p(File.join(dir, 'objc'))
  File.write(File.join(dir, 'objc/blocks_runtime.h'), "#pragma once\n")
  input = File.join(dir, 'probe.m'); output = File.join(dir, 'probe')
  File.write(input, program)
  abort 'compile failed' unless system('clang', '-O0', '-fblocks', '-fobjc-runtime=gcc',
    '-fconstant-string-class=NSConstantString', "-I#{dir}",
    "-I#{sdk}/usr/include/GNUstep", "-I#{gcc.strip}", input,
    "-L#{sdk}/usr/lib", "-Wl,-rpath,#{sdk}/usr/lib", '-lgnustep-base', '-lobjc',
    '-pthread', '-o', output)
  abort 'probe failed' unless system(output, rlimit_core: 0)
end
