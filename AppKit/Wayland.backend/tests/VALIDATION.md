# Wayland validation record

This records the September 15–16, 2026 validation of the opt-in backend. It is
fixture coverage, not a claim that the available Apple applications work.
Reproduction controls for both checked-in fixtures are in the [backend
README](../README.md).

## Published implementation units

| Commit | Completed scope | Included fixture/documentation |
|---|---|---|
| `013826c0` | M1 toplevels, CPU shm drawing, pointer/keyboard input, opt-in selection and fallback | Protocol opcode checks and native ABI design |
| `69e93fd1` | Image cursors, immutable pixel storage and logical hotspots | `waylandtest.m`, image-cursor reproduction notes |
| `3ef63c44` | M2 integer output scaling, nested popup menus and negotiated client decorations | HiDPI/popup fixture modes, decoration instructions |
| `3feac01c` | M3 clipboard portion: UTF-8 selections, bounded transfers, ownership and local named boards | `clipboardtest.m`, transfer-limit and reproduction notes |

These commits are on the branch backing
[PR #87](https://github.com/VibeDarling/darling-cocotron/pull/87).
Image cursors and clipboard are separate implementation commits. The M2 commit
keeps scaling, popup coordinate conversion and client-frame offsets together.
Drag/drop and EGL/OpenGL subwindows are not implemented.

## Environment and successful checks

The fixtures are plain arm64 AppKit executables. Wayland tests used a private
headless Sway compositor with the pixman renderer, virtual-pointer input,
`wtype`, and `grim` screenshots. X11 checks used an isolated Xvfb server.
The backend was compiled and linked into private output directories against the
Darling build-tree libraries; it was copied only into a dedicated test prefix.

| Area | Observed result |
|---|---|
| Native ABI | Private compile/link passed; 35 fixed-arity native functions, no variadic entries and no direct `wl_*`/`xkb_*` imports |
| M1 behavior | Drawing, pointer/scroll coordinates, Romanian typing, Return, repeat/modifiers, resize, hide/show and close delivery passed |
| Image cursors | Eight screenshot samples exactly match opaque, transparent and half-alpha reference colors at 1x; hotspot/orientation checked |
| HiDPI | 1x → 2x → 1x transitions passed; the half-point stripe occupies exactly one physical pixel at 2x |
| Popups | Nested `xdg_popup` roles and grabs observed; keyboard submenu navigation and outside cancellation return zero actions, with both server and client decorations |
| Client decorations | Close delivery passed; title dragging and border resizing changed compositor geometry; maximize/minimize requests were delivered |
| X11 compatibility | Default selection and typing passed; unavailable Wayland socket produced one fallback diagnostic and X11; both fixture processes exited naturally with status 0 |
| Clipboard | Unicode both directions, 2,100,000-byte transfers, lazy providers, ownership replacement after clear, unsupported types, clearing and an early-closing reader passed; fixture exited naturally with status 0 |
| Clipboard bounds | Stalled owner returned nil after 5.03 seconds; a 17 MiB offer was rejected with the size-limit diagnostic, rather than returned partially |

The Wayland window harness stops the remaining app during cleanup. Its success
status establishes close delivery and cleanup, not natural application exit.
Compositor policy determines whether maximize/minimize changes visibility or
geometry; request delivery alone is not a policy-independent action pass.

The clipboard boundary tests were strengthened after an intermediate run
returned nil immediately because local ownership survived a clear operation.
That bug was fixed before `3feac01c`; only the final timed and size-diagnostic
checks support the boundary claims above.

## Limits and separate app work

- At 2x, sampled image-cursor colors differ from the 1x reference by up to two
  channel values. This discrepancy is not presented as an exact pixel match.
- Multiple physical outputs, fractional scaling, clipboard-manager persistence
  after application exit, primary-selection protocols and rich-format conversion
  have not been validated or implemented as described in the README.
- The `UNPREMULT_CURSOR=1` diagnostic passes eight exact pixel samples with a
  separate private Onyx2D straight-alpha fix. That shared renderer fix is not
  part of the Wayland branch; the normal fixture uses premultiplied input.
- A separately authorized installed-only X11 Apple-app batch reached TextEdit's
  loader and aborted with missing `_malloc_type_calloc` in `libSystem.B.dylib`
  (exit 134), before any window or basic action. The batch stopped there and the
  other five apps were not attempted. This is an installed-library blocker,
  not a Wayland app pass or a clean exit. A subsequent installed allocator probe
  passed 12 checks, but the Apple-app rerun is still pending; that probe does not
  establish successful TextEdit startup.
- Earlier Apple-runner attempts stopped during container bootstrap because of
  overlong Unix socket paths. They provide no app compatibility evidence. The
  corrected physical-prefix layout passed its bootstrap control; runtime
  cleanup and shared test-lock release were verified after each attempt.

Machine-specific build scripts, app authorization manifests, disposable-prefix
runners and screenshots remain local test artifacts. The portable fixture
sources and manual reproduction controls are checked in here.
