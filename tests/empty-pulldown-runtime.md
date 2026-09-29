# Empty pull-down title regression

Compile `empty-pulldown-runtime.m` against Darling AppKit with assertions
enabled, then run it in a Darling GUI guest using the candidate framework:

```sh
clang -UNDEBUG empty-pulldown-runtime.m -framework AppKit -o empty-pulldown
./empty-pulldown
```

Require exit zero and `PASS: empty pull-down titles and existing selection`.
The test covers a title assigned to an empty pull-down menu, repeated title
replacement without appending items, preserving an existing selected command,
resetting to an empty title after removing all items, and ordinary pop-up
title/selection behavior.

Validation used ARM64 Darling, rebuilding candidate NSPopUpButton and the same
upstream NSMenu into the staged AppKit framework. Other framework objects and
dependencies remained staged. The equivalent baseline rebuild from upstream
e1132ba8 throws on the first empty pull-down title assignment. This is not a
clean full-framework build, x86_64 runtime test, complete iTerm2 launch, or
native macOS comparison.

Apple's setTitle: documentation requires setting the pull-down title but does
not specify empty-menu item counts. Creating its first title item follows
Darling's existing first-menu-item storage model; the test's item-count checks
are implementation invariants, not claims of independently measured macOS
behavior.

https://developer.apple.com/documentation/appkit/nspopupbutton/settitle(_:)?language=objc
