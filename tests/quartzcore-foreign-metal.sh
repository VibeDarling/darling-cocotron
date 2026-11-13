#!/usr/bin/env bash
# Builds the guest test and the foreign-Metal stub; see quartzcore-foreign-metal.md.
# usage: quartzcore-foreign-metal.sh BUILD OUT
#   BUILD  a Darling build directory with AppKit and QuartzCore built (ninja QuartzCore)
#   OUT    scratch directory that receives qcm, foreign/Frameworks and darling/Frameworks
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 BUILD OUT" >&2; exit 2; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build=$(cd -- "$1" && pwd)
mkdir -p "$2"
out=$(cd -- "$2" && pwd)

python3 -I - "$root/tests" "$build" "$out" <<'PY'
import pathlib, shlex, subprocess, sys

tests, build, out = (pathlib.Path(a) for a in sys.argv[1:4])
commands = subprocess.check_output(["ninja", "-C", str(build), "-t", "commands", "AppKit"], text=True).splitlines()
original = shlex.split(next(c for c in commands if " -c " in c and "/NSView.m" in c))
flags, i = [], 0
while i < len(original):
    if original[i] in ("-o", "-c", "-MT", "-MF"):
        i += 2
    elif original[i] in ("-MD", "-MMD"):
        i += 1
    else:
        flags.append(original[i])
        i += 1
# The stub is plain C: drop the Objective-C prefix header and the AppKit export define.
c_flags, i = [], 0
while i < len(flags):
    if flags[i] == "-include":
        i += 2
    elif flags[i] == "-DAppKit_EXPORTS":
        i += 1
    else:
        c_flags.append(flags[i])
        i += 1

cc = flags[0]
target = flags[flags.index("-target") + 1]
linker = build / "host-tools-build/ld64" / (target + "-ld")
link = next(c for c in commands if " -o src/external/cocotron/AppKit/AppKit " in c)
maps = [a for a in shlex.split(link) if "-dylib_file," in a]
libsystem = "src/external/libsystem/libSystem.B.dylib"

def run(args):
    subprocess.run(args, cwd=build, check=True)

run(c_flags + ["-c", str(tests / "quartzcore-foreign-metal-stub.c"), "-o", str(out / "stub.o")])
run(flags + ["-c", str(tests / "quartzcore-foreign-metal.m"), "-o", str(out / "qcm.o")])

metal = out / "foreign/Frameworks/Metal.framework/Versions/A/Metal"
metal.parent.mkdir(parents=True, exist_ok=True)
run([cc, "-target", target, "-nostdlib", "-dynamiclib", "-fuse-ld=" + str(linker),
     "-Wl,-install_name,/System/Library/Frameworks/Metal.framework/Versions/A/Metal",
     "-Wl,-compatibility_version,1.0.0", "-Wl,-current_version,1.0.0",
     *maps, "-o", str(metal), str(out / "stub.o"), libsystem])

run([cc, "-target", target, "-nostdlib", "-fuse-ld=" + str(linker),
     "-Wl,-Z", "-Wl,-platform_version,macos,11.0,11.0",
     *maps, "-o", str(out / "qcm"), str(out / "qcm.o"),
     "src/external/foundation/Foundation", "src/external/objc4/runtime/libobjc.A.dylib", libsystem])
PY

for side in foreign darling; do
    dir=$out/$side/Frameworks/QuartzCore.framework/Versions/A
    mkdir -p "$dir"
    cp "$build/src/external/cocotron/QuartzCore/QuartzCore" "$dir/QuartzCore"
done
rm -f "$out/stub.o" "$out/qcm.o"
echo "built $out/qcm, $out/foreign/Frameworks, $out/darling/Frameworks"
