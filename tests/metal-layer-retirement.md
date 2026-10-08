# Retired native layer windows

The fixture uses public AppKit and Metal APIs. Replacing a window's content view
and adding a layer-backed child briefly creates native root-layer windows.
Their autorelease lifetime must not keep retired windows visibly mapped over the
active layer. The fixture clears its 300x200 drawable red, and a real `b` key event
changes it to blue. Keep the outer autorelease pool alive during verification.

Build against an existing Metal-enabled Darling build:

```sh
flock /tmp/agent-locks/darling-heavy-build.lock \
  python3 tests/build-metal-layer-retirement.py "$BUILD" "$SCRATCH/metal-layer-retirement"
```

Use the build's non-setuid launcher, a private committed staged runtime, and a
fresh private prefix. On an isolated Xvfb display (1280x800, no TCP):

```sh
env -u DBUS_SESSION_BUS_ADDRESS DISPLAY=:94 DPREFIX="$PREFIX" \
  DARLING_INSTALL_PREFIX="$IMAGE/usr/local" "$LAUNCHER" shell \
  env -u DBUS_SESSION_BUS_ADDRESS DISPLAY=:94 DARLING_ENABLE_METAL=1 \
  DARLING_APPKIT_BACKEND=x11 "$GUEST_FIXTURE"
```

Wait for `CAPTURE_READY`. Capture with `DISPLAY=:94 magick import -window root
red.png`. There must be exactly 60000 pixels with R>240, G<15 and B<15. Inspect
`DISPLAY=:94 xwininfo -root -tree`; only the active native child may be viewable.
Focus the fixture's freshly inspected parent ID with `xdotool windowfocus --sync
<ID>`, then `xdotool key b`. The guest must print `INPUT blue`, and a new capture
must contain exactly 60000 blue pixels (B>240, R/G<15). Optional global-menu D-Bus
service is explicitly unavailable in this test environment.

On native headless Sway, disable Xwayland and keep the fixture floating at its
requested 300x200 size to isolate this test from resize transactions. Run with
`DARLING_APPKIT_BACKEND=wayland`, `DISPLAY` unset and the private compositor's
`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`; capture using `grim`. Require the same 60000
red pixels. Send Linux evdev key 48 (`b`) using a virtual keyboard with the
standard evdev/pc105/us XKB keymap, zero initial modifiers and a two-second
keymap setup delay. Require `INPUT blue` and exactly 60000 blue pixels.
Custom keymaps such as wtype's can assign different physical keycodes; they
do not establish this fixture's hardware-key translation result.
Always stop each prefix using the same launcher with `darling shutdown`.

Measured 2026-10-08: upstream ec245a01 fixture captures 0 red pixels on X11;
candidate captures 60000 red and 60000 blue after a real X11 key event, with one
viewable child and two retired children unmapped. Native Wayland candidate
captures 60000 red pixels with Xwayland disabled; standard evdev key 48 then
produces `INPUT blue` and exactly 60000 blue pixels.
Actual DodgeDanger rendering/interaction remains a separate shader/pipeline
verification requirement; this fixture alone does not establish app success.
