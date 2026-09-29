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

The candidate now computes shortcut characters with a separate XLookupString
lookup retaining only Shift and the active layout group. Normal input text and
XIM processing remain unchanged. This follows Apple's documented
[charactersIgnoringModifiers contract](https://developer.apple.com/documentation/appkit/nsevent/charactersignoringmodifiers).
`tests/x11-shortcut-characters.c` exercises the actual helper against Xvfb's
default US layout: 1,024 letter/punctuation, press/release, modifier-mask cases
pass, and the original event state remains unchanged. These checks do not yet
cover XIM-composed input, non-US layouts, or end-to-end AppKit dispatch.

`bash tests/x11-shortcut-layouts.sh` now covers US letters/punctuation, French
ampersand/1, and the same physical Y key in US versus German layout groups.
All 2,560 press/release/modifier combinations pass against real Xlib and Xvfb.
The active group is preserved rather than forcing the first layout. This adds
non-US/group evidence, but still does not establish XIM or full AppKit dispatch.

`x11-shortcut-xim.c` adds a real local XIM (`@im=none`, C.UTF-8) smoke test.
Compile with `cc tests/x11-shortcut-xim.c -lX11 -o /tmp/x11-shortcut-xim` and run
with `xvfb-run -a /tmp/x11-shortcut-xim`. Basic Shift, Caps Lock and Control
lookups pass: shortcut lookup leaves the entire event unchanged and subsequent
Xutf8LookupString returns identical text, status and keysym. Caps Lock text stays
uppercase while shortcut characters ignore Caps Lock. This is not composition
or remote input-method coverage.

The guest `menu-modifiers-runtime.m` now passes the actual NSMenu/NSMenuItem/
NSApplication dispatch matrix, implicit Shift and disabled-item checks with a
candidate NSMenu object linked into the staged AppKit framework. Staged AppKit
fails the modifier matrix; the first candidate exposed disabled-item dispatch,
fixed by checking isEnabled before dynamic validation. The guest test supplies
NSEvent objects directly: X11 event translation and menu dispatch are separately
tested, not yet one end-to-end injected-key test or a fresh full framework build.
