# Wayland AppKit backend

Select with `DARLING_APPKIT_BACKEND=wayland`. Without it, AppKit uses X11. If the
compositor or required native libraries cannot be reached, the backend logs the
reason and falls back to X11. `WAYLAND_DISPLAY` must be a **host filesystem path**
when passed through Darling; native libwayland resolves it outside the container.

Supported: xdg-shell toplevels, CPU drawing via wl_shm, pointer and keyboard input,
compositor keymaps, repeat, resize, hide/re-show, compositor close, themed cursors
and NSImage cursors. Images use immutable premultiplied ARGB storage and retain
their hotspot. Invalid image dimensions or nonfinite hotspots fall back to the arrow; finite
hotspots are clamped to the image bounds.
Native cursor buffers belong to the display, so an AppKit cursor can outlive its
Wayland connection. Image cursors do not require libwayland-cursor or a theme.

## Manual regression application

Build `tests/waylandtest.m` as a plain arm64 executable linked against AppKit with
your Darling SDK/toolchain. It does not need pointer authentication disabled.
Run it in a dedicated test prefix and compositor; set `DARLING_APPKIT_BACKEND` to
`wayland` and `WAYLAND_DISPLAY` to the compositor's host socket path.

The application draws red/green/blue views, a text view, and a second yellow window.
It logs input events, text, geometry, activation, and close delivery. Right-click
the red view to hide/re-show the second window. `EXIT_AFTER` controls its exit
timer (seconds); keep the second window visible while testing close on the first.

Set `IMAGE_CURSOR=1` to register a 32x24 image cursor over the red view, with
hotspot (5,7). With the pointer held over that view, capture using `grim -c`:

- Left 16 columns: magenta upper half, cyan lower half.
- Next 8 columns: transparent, preserving the red background.
- Right 8 columns: half-alpha magenta/cyan, blending over red.
- The image starts five pixels left and seven pixels above the pointer.

Move into the text view to restore the themed I-beam. Leave/re-enter the window,
resize it, and hide/re-show the second window. Test Romanian text `Hello ăîșț`,
key repeat and modifiers, then compositor close (`windowWillClose` in the log).

Also run without the selector variable on an isolated X server to verify
`backend X11Display` and typing, then with Wayland selected and an invalid socket:
one fallback message and an X11 window should result.

`UNPREMULT_CURSOR=1` selects an additional shared-renderer diagnostic: it uses
an unpremultiplied NSBitmapImageRep. Onyx2D's current 8-bit image reader does not
correctly premultiply this input, so transparent/partial-alpha pixels can render
incorrectly. The normal fixture supplies premultiplied data to test the backend
independently of that shared drawing issue.

## HiDPI, menus and decorations

Surface output membership controls integer HiDPI rendering and cursor scale.
Set `HIDPI_TEST=1` and change the test output between scale 1 and 2: the half-point
white stripe in the red view should become one physical pixel wide at scale 2.
Input coordinates and AppKit window dimensions remain logical.

Menus use `xdg_popup` with parent-relative placement and nested grabs.
`POPUP_TEST=1` opens a context menu from the green view. Open its Branch submenu,
then click outside; cancellation must log `popup returned actions=0`.
Repositioning requires xdg-shell version 3.

Titled windows negotiate decorations and draw a client frame when requested by
the compositor or when the decoration protocol is absent. Set
`DARLING_WAYLAND_DECORATIONS=client` to request this path explicitly. Test close,
minimize, maximize, title-bar move and border resize. Compositor policy determines
final placement and supported actions.

Headless Sway validation covers 1x/2x/1x transitions, nested menu grabs and
outside-click cancellation, typing, resize, hide/show and client close delivery.
Client title dragging and border resizing change compositor geometry; maximize
and minimize requests are delivered, with final behavior governed by policy.
The half-point stripe is exactly one physical pixel at 2x. Image-cursor colors
at 2x currently differ by up to two channel values from the 1x reference.
Multiple physical outputs and fractional scales have not been validated.

## Clipboard

The general pasteboard uses `wl_data_device`. UTF-8 text maps to
`text/plain;charset=utf-8`, `text/plain` and `UTF8_STRING`; other pasteboard types
are exposed under their own names. Other named pasteboards are process-local.
Publishing requires keyboard focus and an input serial; writes made beforehand
remain local until input is available. Providers are materialized outside native
Wayland dispatch, and each published source uses an immutable snapshot.

Transfers are limited to 16 MiB and five seconds. A dedicated writer keeps a slow
reader off the UI thread and handles broken pipes without changing process-wide
SIGPIPE behavior. Synchronous reads service compositor events while waiting and
return nil on timeout, oversize or ownership replacement, never truncated data.

Build `tests/clipboardtest.m` like the window fixture. Set `CLIPBOARD_INPUT` and
`CLIPBOARD_RESULT` to dedicated guest-accessible scratch files. With its window
focused, `c` copies input bytes as UTF-8 text, `l` declares a lazy provider, `p`
writes received text bytes to the result file, `u` checks an unsupported type,
`e` clears, `r` checks a failing bounded read, and `q` exits. Native `wl-copy` and
`wl-paste` can exercise both directions on the same private compositor.

Validated: Unicode both ways, 2.1 MB transfers, lazy providers, replacement after
clear, early reader closure, a 5.03-second stalled-owner timeout, 17 MiB rejection
and natural fixture exit0. This is fixture coverage, not real Apple-app coverage.

## Remaining milestones

M3 drag/drop and M4 EGL/OpenGL subwindows remain. Primary-selection protocols,
clipboard-manager persistence after app exit and rich-format conversion are not
implemented.

All native calls use fixed-arity functions; requests use
`wl_proxy_marshal_array_flags`, and events use a dispatcher to avoid the
Darwin/Linux arm64 variadic and listener ABI differences.
