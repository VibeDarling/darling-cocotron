# Menu modifier regression checklist

Pending runtime execution. Use enabled menu items with distinct logging targets;
ensure no key window or application delegate intercepts the key first.

- Lowercase `q` + Command: Command-Q activates; Control-Command-Q does not.
- Lowercase `q` + Control-Command: Control-Command-Q activates; Command-Q does not.
- Uppercase `Q` + Command (no explicit Shift): Shift-Command-Q activates.
- Uppercase `Q` + Shift-Command: Shift-Command-Q still activates.
- Repeat Control discrimination with a function key whose character is unchanged
  by the modifier. This isolates mask matching from letter case conversion.
- Verify disabled items and items failing validation do not invoke actions.
- Repeat in a submenu and check the correct item is the action sender.
- Test Caps Lock, shifted punctuation, explicit Shift with lowercase equivalents,
  and non-US keyboard layouts against macOS before promoting from draft. The
  change preserves exact character matching; it does not normalize key strings
  or repair backend charactersIgnoringModifiers generation.
# Executable control-flow test

Run `ruby tests/menu-modifiers.rb GNUSTEP_ROOT`. This extracts the actual
performKeyEquivalent method and uses GNUstep strings/arrays with controlled
event, validation and action-dispatch adapters. It tests all 256 combinations
of the four modifier bits, unrelated flags, implicit uppercase Shift, exact
character matching, a rejected validation result, action failure, submenu
traversal and an empty menu. The candidate passes; the upstream matching method
fails the modifier matrix. The adapter does not execute itemIsEnabled itself.

This is not a GUI or keyboard-layout test. In particular, preserving exact
string comparison does not establish the documented equivalence of lowercase
plus explicit Shift with an uppercase key. The remaining checklist below still
applies; Caps Lock and layout-dependent character production need real events.
