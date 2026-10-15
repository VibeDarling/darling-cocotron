Build `coregraphics-image-headroom.c` against the rebuilt CoreGraphics and run it
in a guest. Original PR #424 added the previously missing symbol. Historical QA records
an older runtime failing to resolve `CGImageGetHeadroom` (the symbol the OpenSwiftUI
`SwiftUI.framework` imports), and both PR #429's parent and candidate printing `PASS`.
PR #429 moves the declaration to the private header and adds the NULL-image case;
it has no new behavioral red/green result.
Darling images record no content headroom, so the function reports false and
writes 0.
