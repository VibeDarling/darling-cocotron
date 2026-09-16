# Darling AppKit Wayland backend

This backend draws Cocotron AppKit windows directly on a Wayland compositor.
It is opt-in; X11 remains the default. This combined branch includes the reviewed
input, drag-and-drop and EGL milestones, with the integration limits below.

## Selecting it

Build/install the backend with Darling, then select it for the application:

```sh
export WAYLAND_DISPLAY=/absolute/host/path/to/wayland-socket
darling shell env DARLING_APPKIT_BACKEND=wayland \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" /path/to/application
```

The socket path is a **host** path, not a `/Volumes/SystemRoot` guest path:
native libwayland opens it. Without the selector, AppKit uses X11. Missing native
libraries, unavailable compositor or required globals cause a logged fallback
to the next backend. An older OpenGL runtime without the explicit Wayland EGL
registration API still permits CPU drawing and reports unavailable EGL support.

CMake requires wayland-client >= 1.20, wayland-cursor, xkbcommon,
wayland-protocols headers and wayland-scanner. It skips this backend when build
dependencies are missing. Native libraries load on demand through fixed-arity
Darwin/Linux bridges. Generated protocol tables are checked against request/event
names at startup; native variadic functions and libffi listener dispatch are not
used.

## Implemented and tested

| Area | Behavior and evidence |
| --- | --- |
| Windows | xdg toplevels, redraw/resize, hide/show, popups and client/server decorations; [initial validation](tests/VALIDATION.md) |
| Input | Pointer/click grouping, scrolling, text/repeat and independent physical modifiers; [input validation](tests/INPUT-VALIDATION.md) |
| Scale and cursors | Integer buffer scale, named/image cursors, scaled drag icons; [icon validation](tests/DRAG-ICON-VALIDATION.md) |
| Clipboard and dragging | Clipboard ownership/transfer, incoming/outgoing COPY/MOVE, bounded immutable data; [outgoing](tests/OUTGOING-VALIDATION.md) and [actions](tests/DRAG-ACTIONS-VALIDATION.md) |
| Filenames | Host-backed file URI conversion; [URI limits](tests/FILE-URI-VALIDATION.md) |
| Local-only dragging | Original Cocoa bytes stay in process, including guest-only paths; [privacy/lifecycle validation](tests/LOCAL-DRAG-VALIDATION.md) |
| OpenGL/layers | Main-thread EGL subwindows, NSOpenGLView/layer presentation, integer scale and parent clipping; [combined interactions](tests/COMBINED-VALIDATION.md) |

The [combined fixture](tests/integrationtest.m) exercises these components in the
same application: input through GL children, modifier changes during a held mouse
press, drag cancellation/remapping and live 1x→2x scale changes. Its framework
composition and exact evidence are recorded separately from installed readiness.

## Remaining gaps and compositor constraints

- No fractional-scale protocol, pointer constraints/relative pointer, or global
  pointer warping. Integer 1x/2x rendering does not establish fractional coverage.
- Toplevel position/focus/stacking are compositor-controlled. Reported positions
  and drag-end coordinates use the backend's virtual origin. Minimized state is
  not reported by xdg-shell; `isMiniaturized` cannot reflect it reliably.
- Whole-window alpha, explicit shadow control, attention requests and cursor
  capture are not implemented. CoreGraphics global window-server queries are
  not supplied by this backend.
- Guest-only file export to other processes, file promises, modern dragging
  sessions, ASK UI and slide-back remain absent. Core drag actions lack LINK.
  Different simultaneous local/external action sets are not negotiated separately.
- EGL presentation on background threads is rejected. Arbitrary ancestor clipping
  and complete mixed-view stacking are not established. The companion explicit
  EGL registration API and AppKit/QuartzCore presentation hooks are required.
- Private headless-compositor tests do not prove every desktop compositor, input
  device, monitor transition, accessibility/IME path, or macOS application works.

See each validation note for precise coverage and failure cases. This is a
working set of backend milestones, not full macOS window-server parity.
