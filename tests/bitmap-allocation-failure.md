# Bitmap allocation failure regression

`ruby tests/build-bitmap-allocation-probe.rb` prints a complete Objective-C test
translation unit. Compile it against AppKit/Foundation/CoreGraphics and run the
result under Darling. Alternatively, pass a Ruby build-helper path that accepts
one source-file path to compile and link it using an existing Darling SDK setup.

The generated category contains the source tree's actual initializer and dealloc
methods. Only their NSZoneCalloc/NSZoneFree calls are redirected to fault injection
and allocation/free accounting. Runtime support and the superclass remain real
framework implementations. This is a targeted method test, not a complete rebuilt
AppKit runtime test.

The test fails each of the four allocations in a three-plane image in turn,
including failures after earlier planes succeeded. It requires nil, balanced
allocation/free counts, and no duplicate/unknown frees. Successful owned storage,
failed external plane-table allocation, and successful caller-owned storage are
also checked. Caller-owned arrays must never reach the free wrapper.

Require exit zero and the final PASS marker. The unfixed initializer crashes on
the first injected failure. This test does not cover invalid dimensions, integer
overflow, or every allocator elsewhere in AppKit.
