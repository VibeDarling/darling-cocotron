# Unsupported focus representation

Compile `image-focus-error.m` against AppKit, Foundation and CoreGraphics, then
run it under Darling with the rebuilt AppKit library. No extracted methods or
method replacements are used.

The test creates a real bitmap graphics context and calls the public
`lockFocusOnRepresentation:` method with a representation that cannot supply a
graphics context. It requires NSInvalidArgumentException with the representation
description in its reason and verifies that the original graphics context remains
current. Require exit zero and the final PASS marker.

The unfixed runtime crashes while processing the missing `%@` argument instead
of delivering the expected exception. ARM64 runtime validation is recorded for
this test; x86_64 was not run.
