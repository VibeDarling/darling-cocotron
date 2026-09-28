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
