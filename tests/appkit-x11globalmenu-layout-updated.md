# X11GlobalMenu LayoutUpdated regression

This guest fixture calls `NSApplication`'s real `setMainMenu:` twice, using two
owned empty menus. It subscribes before either call on a separate private libdbus
connection, then checks the actual emitted messages. A successful run prints
`PASS: LayoutUpdated ui 2/0 then ui 3/0 from cached emitter` and exits 0.
Any unmet precondition, disconnection, missing message or invalid payload fails.
This source has not yet been compiled or executed; the verification below is queued.

The subscription binds to the unique name of the retained cached session-bus
connection used by `X11GlobalMenu`. A non-NULL `DBusError` makes `AddMatch` wait
for acknowledgement. Both messages must come from that specific connection,
have signal type, path `/MenuBar`, interface `com.canonical.dbusmenu`, member
`LayoutUpdated`, signature `ui`, and no third argument. The first must decode as
UINT32 revision 2 / INT32 parent 0, the second as revision 3 / parent 0.
Unexpected matching messages are failures; only ordinary bus-daemon messages
are ignored. Initialization currently starts the revision at 1. If initialization
changes to emit updates, review that fixture assumption rather than discarding
messages or weakening the expected revisions.

## Build prerequisites

Use an independently prepared private Darling runtime with the matching Cocotron
AppKit/Foundation and X11 backend. Record source commits, component hashes,
architecture, header configuration, compile/link command and test executable hash.
Wait for the coordinator's heavy-build reservation; do not rebuild or install into
a shared runtime. Reuse a completed runtime as a read-only reference where suitable.

Compile this `.m` as a Darwin guest executable with the runtime's guest compiler,
sysroot and framework search settings, linking AppKit, Foundation, libSystem and
the selected runtime's **Mach-O native libdbus wrapper**. With installation prefix
`/usr/local`, the wrapper's image path is
`<image>/usr/local/libexec/darling/usr/lib/native/libdbus.dylib`, whose guest install
name is `/usr/lib/native/libdbus.dylib`. Do not link host ELF `-ldbus-1` directly.
Use `<dbus/dbus.h>` and its matching architecture-generated `dbus-arch-deps.h`.
The backend already uses `${DBUS_INCLUDE_DIRS}`; select those same include roots
(commonly `/usr/include/dbus-1.0` and `/usr/lib/dbus-1.0/include`). Do not fabricate
`DBusMessageIter` layout or reuse an old compile helper without inspecting its
actual runtime paths and wrapper link contract.

The wrapper is generated from the host ELF's exported functions by the
superproject's `src/native/CMakeLists.txt`, `cmake/wrap_elf.cmake` and
`src/libelfloader/wrapgen/wrapgen.cpp`; there is no source API allowlist to extend.
Public header declarations do not prove exports or guest ABI acceptance in a
particular image. Linking every fixed-signature API used here and executing the
guest remain required gates. No syntax-only check substitutes for them.

## Isolated launch contract

Each variant needs a fresh private `DPREFIX`, its own `dbus-run-session`, and an
owned Xvfb or equivalent display. Clear inherited bus/display settings before
creating those private resources, then set `DARLING_APPKIT_BACKEND=x11` and the
new display. Record any PAC configuration instead of assuming PAC must be disabled.
The fixture requires a nonempty bus address but cannot prove an inherited address
is private. Direct execution against a desktop session bus is unsupported.

Use the runtime's non-setuid build launcher with explicit `DARLING_INSTALL_PREFIX`:

```text
DPREFIX=<fresh-prefix> DARLING_INSTALL_PREFIX=<image>/usr/local \
  <build>/src/startup/darling shell <guest-test-path>
```

These are launch inputs for a separately reviewed external driver, not a complete
standalone shell recipe. That driver must enforce a monotonic deadline over the
**entire launch**, including connection setup, synchronous AddMatch, application
initialization, flush and receive. The fixture's five-second receive budget and
50 ms read intervals do not bound synchronous setup or flush. On external expiry,
request prefix-scoped `darling shutdown` using the same launcher/environment.
Never use `timeout` to kill the guest or signal guest/shared processes. Preserve
logs, prefixes and images; report deadline expiry, guest exit status and orderly
shutdown result separately. If shutdown fails, leave recovery to the coordinator.
Shut down each prefix after normal completion as well.

## Required verification

Use the same test executable and inputs for ABI-compatible parent/candidate
comparisons, with independent private image copies or overlays, matching source
and header inputs, and identical unrelated objects. Record exactly which component
was overlaid; this is not automatically a whole-PR runtime test.

1. Parent: the real variadic LayoutUpdated path must fail without the complete
   PASS marker. Candidate: both exact payloads and exit 0 must be observed before
   teardown. If the parent passes, this runtime did not reproduce the ABI failure;
   report it and do not substitute an unrelated missing-symbol failure.
2. In scratch only, restore just LayoutUpdated's two iterator appends to its
   original single `dbus_message_append_args` call. Rebuild that backend privately;
   the unchanged fixture must fail. Preserve evidence without mutating shared code.
3. Separately mutate only production `rootId` from 0 to 1, keeping iterator calls.
   The same fixture must fail with the payload diagnostic. A fixed-revision
   mutation is another valid wire assertion probe. This does not replace parent
   ABI failure evidence.
4. Verify absent bus/backend produces explicit failure, never skipped success.
   Record match acknowledgement as the readiness barrier, not a sleep. Preserve
   actual guest logs and separate launcher/shutdown statuses for every variant.

Full build acceptance and architecture coverage remain separate gates. Historical
one-update QA logs support the choice of stimulus; they are not new execution proof.

## Provenance and coverage

The stimulus follows the authored QA `gm/menu-test.m`: initialize NSApplication
and set a main menu. Only the signature/value assertion idea is reused from the
authored standalone D-Bus ABI probe; its guessed iterator layout is not reused.
Clean-room rung 2 supplies the real caller and protocol contract from
`AppKit/NSApplication.m`, `AppKit/X11.backend/X11GlobalMenu.h` and `.m`:
`sharedGlobalMenu`, instance `isAvailable`, `_revision = 1`, increment per update,
and the `LayoutUpdated` signal's `u` revision / `i` parent. Public libdbus headers
and the [bus API documentation](https://dbus.freedesktop.org/doc/api/html/group__DBusBus.html)
supply the fixed APIs, shared/private connection semantics, retained unique-name
lifetime and synchronous AddMatch contract. No Apple binary implementation is used.

This fixture covers **1 of 5 replaced variadic call sites and 2 of 7 appended
values**: LayoutUpdated's UINT32 revision and INT32 root, order, signature and
repeated messages through the real production helper. It does not exercise
Introspect STRING, AboutToShow BOOLEAN, RegisterWindow UINT32/OBJECT_PATH or
UnregisterWindow UINT32. It makes no claim about allocator failures, nil-title
conversion, Wayland, x86_64 behavior, window mapping or Image Capture success.
