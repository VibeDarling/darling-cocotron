Build `coregraphics-image-headroom.c` against the rebuilt CoreGraphics and run it
in a guest. Before the change the link fails with an undefined `CGImageGetHeadroom`
(the symbol the OpenSwiftUI `SwiftUI.framework` imports); after it the program prints
`PASS`. Darling images record no content headroom, so the function reports false and
writes 0.
