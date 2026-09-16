# Wayland input regression

`inputtest.m` is a plain-arm64 AppKit fixture. Build it like `waylandtest.m`,
select this backend using `DARLING_APPKIT_BACKEND=wayland`, and run it against a
private compositor with Xwayland disabled. It logs generated AppKit events and
exits after 18 seconds. It consumes input in `sendEvent:`; it does not validate
responder-chain delivery.

Inject the following into its content area:

1. Two left clicks at the same point, 60 ms apart: down/up counts `1,1,2,2`.
2. Move 50 logical pixels, then left-click immediately: counts `1,1`.
3. Immediately right-click at that point: counts `1,1`.
4. Press/release Shift, Control, Alt and Logo: `NSFlagsChanged` (`type=12`)
   with masks `131072`, `262144`, `524288`, `1048576`, each followed by zero.
5. Focus an independent native client while leaving the pointer above the test
   window. Hold Shift: no keyboard event may reach the unfocused test app.
   Focus the test app while Shift remains held: Shift flags must synchronize,
   followed by zero on release.

The physical key identity is only known when a preceding `wl_keyboard.key`
identifies it. Virtual keyboard mask changes and focus synchronization use
`keyCode=0xFFFF` (unknown). The compositor's modifiers event is authoritative.
This change emits **aggregate modifier transitions**; pressing another side of
an already-held modifier need not change the aggregate mask and is not emitted
as a separate event. Full independent left/right physical-state reporting is a
follow-up, not claimed here.

## Recorded validation, 2026-09-16

Isolated headless Sway, installed isolation-safe Darling launcher, fresh short
prefixes, serialized test locks, no Apple apps or PAC overrides:

- Historical backend: click counts incorrectly continue `1,2,3,4`; no modifier
  events for the four injected mask transitions.
- Candidate: click counts `1,2,1,1`; all four flags and releases correct.
- Final candidate: focus exclusion and held-Shift synchronization pass.
- All three fixtures exit zero; shutdown succeeds; no owned processes remain.
- Private backend compile and native-ABI audit pass (35 fixed-arity functions,
  no direct Wayland/XKB imports).
- Fresh Astra adversarial review identified stale button/count state after
  focus loss; the implementation clears both on pointer leave/window unmap.

Durable evidence: `darling-gui/privbuild/wayland/input/run-baseline/`,
`run-fixed/`, `run-focus/` (app logs, original captures and status files).
Final tested backend SHA256:
`4a9a3592e83ff6bf2f60e5d7ef098320202866f781226364ee2980e3b8bc2720`.
No explicit runtime coverage is claimed for timestamp wrap, every physical
modifier keycode, Caps Lock, or disappearing-window chords; those paths received
source review.
