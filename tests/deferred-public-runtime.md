# Deferred images: rebuilt-framework runtime check

## Patterned crop comparison (2026-09-29)

The four-quadrant central crop is compared against an independently painted
ordinary bitmap at destination density. All four runtime configurations pass
with zero byte differences under identity, reflection, exact quarter-turn and
trigonometric quarter-turn transforms; repeated cropped draws reuse the cache.
Identity, reflection and exact quarter-turn also match direct vector fills.
The trigonometric matrix produces vector-versus-raster differences up to 7/10
byte levels at 1x/HiDPI, shared by the ordinary bitmap reference. That comparison
is diagnostic, not an assertion that raster and vector edge coverage coincide.
The raster comparison remains mandatory with a one-byte maximum in every case.

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

Caller failure handling is tested by temporarily replacing the bitmap initializer
with a one-shot nil result, restoring the original implementation in `@finally`.
The failed draw must not call the handler, change destination bytes, or change
the current graphics context. Retrying must create the bitmap and render once;
the next draw must reuse it. This is caller-level nil injection, not heap-pressure
testing; `bitmap-allocation-failure.m` separately checks actual initializer cleanup.
Handlers that return NO or throw after painting their temporary context are also
checked for unchanged destination/context, correct exception propagation, and
successful retry followed by reuse.

The probe also compares four device-RGB colors (opaque, half/quarter alpha, and
fully transparent), each with copy and source-over compositing, under identity,
horizontal reflection, and quarter-turn destination transforms. Both paths start
from identical zeroed storage before painting the same background: rotated edges
may have fractional coverage and must not retain pixels from a previous case.
The maximum accepted byte difference is one level for intermediate quantization;
the validated four-environment matrix currently reports zero for all 96 comparisons.

A separate transform sequence draws an 8x10 image into a fractional 9.5x7.25
destination under nonuniform scaling, shear, and a 0.37-radian rotation. The
callback verifies physical bitmap dimensions and independent X/Y device density
against the rounded destination-axis lengths. Returning to the first transform
must reuse its prior raster (callback counts 1,2,3,3). Each draw must produce
nonempty output. This checks density and cache identity, not exact edge coverage
or interpolation quality for arbitrary transforms.

The extracted-method fixture in `build-deferred-factory-probe.rb` additionally
covers patterned/cropped output, failure and exception cleanup, appearance,
ownership, and over-budget transient rasters. Its
`TEST_EXPECT_WINDOW_SCALE=1` setting now checks the intermediate representation's
pixel/logical-size ratio: the intermediate is a bitmap, not a window.

These tests do not establish wide-gamut/high-depth color-space fidelity,
pixel-exact arbitrary rotation/shear, real heap-exhaustion behavior, or full
iTerm2 compatibility. The implementation uses an 8-bit device-RGB intermediate.
