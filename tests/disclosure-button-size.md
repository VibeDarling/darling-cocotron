# Disclosure button sizing

Build `disclosure-button-size.m` as an Objective-C executable linked to AppKit
and Foundation, then run with the candidate AppKit and its bundled images in
a graphical Darling session. Success prints `PASS disclosure button...`.

The test uses real NSButton/NSButtonCell and the bundled disclosure glyph.
It checks that sizeToFit accommodates the glyph with no explicitly assigned
image, remains stable when toggled or highlighted, ignores the undrawn title,
and leaves ordinary image-only button sizing dependent on the explicit image.

On the pre-fix implementation, the glyph is 13x13 but the small disclosure
button fits to 8x4, failing the first size assertion. With the fix it fits to
21x17 and all assertions pass in the ARM64 staged guest.

The changed public-source NSButtonCell.m also compiles with the staged ARM64
recipe. Runtime testing used a partial rebuilt AppKit with other pending fixes,
not a clean build of this PR alone. The cellSize implementation is identical
between that runtime candidate and this PR.

Unmodified iTerm2 3.6.11 now shows the entire collapsed quit-dialog accessory
label and disclosure glyph in that runtime, and confirming quit exits the app.
This does not establish constraint solving or expanded accessory behavior.
