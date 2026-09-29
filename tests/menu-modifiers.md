# Menu modifier regression checklist

Pending full AppKit/backend runtime execution. Use enabled menu items with distinct logging targets;
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
  change accepts uppercase event spellings for lowercase equivalents with
  explicit Shift; it does not repair backend charactersIgnoringModifiers
  generation or implement keyboard-layout mapping.
# Executable control-flow test

Run `ruby tests/menu-modifiers.rb GNUSTEP_ROOT`. This extracts the actual
performKeyEquivalent method and uses GNUstep strings/arrays with controlled
event, validation and action-dispatch adapters. It tests all 256 combinations
of the four modifier bits, unrelated flags, implicit uppercase Shift, exact
character matching, a rejected validation result, action failure, submenu
traversal and an empty menu. The candidate passes; the upstream matching method
fails the modifier matrix. The adapter does not execute itemIsEnabled itself.

This is not a GUI or keyboard-layout test. Lowercase-plus-explicit-Shift now
passes with uppercase event characters, including an accented-letter case.
Caps Lock and layout-dependent character production still need coverage.

## X11 fallback lookup observation

On an Xvfb default layout, real XLookupString calls return keysym X for x with
Shift alone or Caps Lock alone, and keysym x with Shift plus Caps Lock. Control
changes the returned text bytes to 0x18 but preserves the x/X keysym. Shift+1
returns the exclamation keysym. X11Display's fallback currently converts this
keysym directly to charactersIgnoringModifiers. Thus the host method matrix's
unrelated Caps Lock bit does not cover real Caps Lock event production: it
supplies characters manually. This remains a backend/normalization gap, and the
PR stays closed pending a supported event-character policy and dispatch tests.
The observation covers XLookupString, not the XIM/Xutf8LookupString path.
