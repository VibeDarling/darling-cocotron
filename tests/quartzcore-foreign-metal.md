# QuartzCore against a Metal without Darling's private classes

QuartzCore may import only public symbols from Metal. `CAMetalDrawable` once did
`[MTLTextureInternal alloc]`, which made QuartzCore import
`_OBJC_CLASS_$_MTLTextureInternal`, a private export of Darling's Metal. Under a macOS
dyld shared cache, Metal is the system one and lacks that class, so dyld stopped while
binding QuartzCore: `Symbol not found: _OBJC_CLASS_$_MTLTextureInternal`.

`quartzcore-foreign-metal.m` loads QuartzCore with `dlopen`. The `foreign` mode runs it
against `quartzcore-foreign-metal-stub.c`, a Metal that exports only
`MTLCreateSystemDefaultDevice`; the `darling` mode runs it against Darling's Metal and
checks that the class QuartzCore looks up by name still exists.

Build against a Darling build that has QuartzCore built from the tree under test
(`ninja QuartzCore`); `tests/quartzcore-foreign-metal.sh` builds the test binary, the stub
Metal (install name `/System/Library/Frameworks/Metal.framework/Versions/A/Metal`,
version 1.0.0, guest architecture) and stages that build's QuartzCore beside each:

```sh
tests/quartzcore-foreign-metal.sh "$BUILD" "$SCRATCH/qcm"
```

Run both modes in the guest, with the stage on `DYLD_FRAMEWORK_PATH` so the prefix's own
QuartzCore and Metal are not used (`$GUEST_SCRATCH` is `$SCRATCH` as the guest sees it):

```sh
DYLD_FRAMEWORK_PATH=$GUEST_SCRATCH/qcm/foreign/Frameworks $GUEST_SCRATCH/qcm/qcm foreign
DYLD_FRAMEWORK_PATH=$GUEST_SCRATCH/qcm/darling/Frameworks $GUEST_SCRATCH/qcm/qcm darling
```

Expected: `PASS: QuartzCore with foreign Metal` and `PASS: QuartzCore with darling Metal`.
With a QuartzCore from before the change, the first run exits 1 with
`FAIL: QuartzCore imports MTLTextureInternal from Metal: ... Symbol not found:
_OBJC_CLASS_$_MTLTextureInternal`; any other load failure prints a different message
(`for a reason other than MTLTextureInternal`), so a broken stage cannot pass for the
regression.

Limits. In `darling` mode the test looks the class up by its own copy of the name, so a typo
in the string in `CAMetalDrawable.mm` is not caught here; `tests/metal-layer-retirement.md`
does catch it, because it creates drawables. No test makes a drawable under a foreign
Metal, or reaches the branch that raises when the class is missing.

Provenance: rung 4, observation at the dlopen boundary with an authored stub; rung 2,
Darling's `MTLTextureInternal.h`.
