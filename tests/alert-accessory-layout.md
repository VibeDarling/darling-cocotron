Build `alert-accessory-layout.m` against the rebuilt AppKit with matching
Foundation/CoreGraphics/QuartzCore dependencies and assertions enabled. Run
with a working graphical backend.

The accessory starts at 10x2 points and changes its frame to 200x80 in `layout`.
The test verifies NSAlert dispatches that pending layout before measuring,
reserves space without overlapping buttons, and does not repeat the callback
when layout is no longer dirty. The pre-fix implementation fails the callback
count assertion. This covers subclass-driven frame sizing, not Auto Layout
constraint solving.
