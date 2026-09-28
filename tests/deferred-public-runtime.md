# Deferred images: rebuilt-framework runtime check

Compile `deferred-public-runtime.m` as an Objective-C Mach-O executable against
AppKit, Foundation, and CoreGraphics. Run it under Darling with the candidate
AppKit and its matching graphics/Foundation dependencies, using the X11 backend
and an available X server (Xvfb is sufficient). This test uses real public
NSImage methods, not the extracted-method fixture.

Run these environment combinations:

| GDK_SCALE | TEST_EXPECT_WINDOW_SCALE | TEST_BITMAP_DESTINATION |
| --- | --- | --- |
| 1 | 1 | unset |
| 1.5 | 1.5 | unset |
| 2 | 2 | unset |
| 2 | 2 | 1 |

Require exit zero **and** the final `PASS: rebuilt public NSImage deferred drawing
and observed window scale` marker. A Darling server exit alone is insufficient.

The checks cover deferred invocation, cache reuse, recache invalidation, actual
window backing width, effective callback device density, and byte-for-byte
comparison of the complete destination buffer against a direct solid fill.
The bitmap case must receive density 1 even though the window/screen is at 2.
Before the bitmap-cache fix, that case aborts with density 2 instead of 1.

The extracted-method fixture in `build-deferred-factory-probe.rb` additionally
covers patterned/cropped output, failure and exception cleanup, appearance,
ownership, and over-budget transient rasters. Its
`TEST_EXPECT_WINDOW_SCALE=1` setting now checks the intermediate representation's
pixel/logical-size ratio: the intermediate is a bitmap, not a window.

These tests do not establish color-space fidelity, arbitrary rotation/shear,
allocation-failure behavior, or full iTerm2 compatibility.
