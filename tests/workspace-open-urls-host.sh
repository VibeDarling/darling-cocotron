#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Runs the real NSWorkspace (NSOpenURLsWithApplication) category of AppKit/NSWorkspace.m on the host against a mock
# NSWorkspace and a minimal mock root class (no Foundation, no LaunchServices). The category is extracted from the
# .m at test time.
# Usage: tests/workspace-open-urls-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2); without it the
#   compiler's default search paths are used. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7),
#   OBJC_LIBS (default "-lobjc -lpthread"), APPKIT_SRC_DIR (another copy of AppKit/, to check the test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${APPKIT_SRC_DIR:-$root/AppKit}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

awk '/^@implementation NSWorkspace \(NSOpenURLsWithApplication\)$/ {on=1; found=1}
     on {print} on && /^@end/ {on=0} END {exit !found}' "$src/NSWorkspace.m" >"$temp/category.inc" ||
    { echo "FAIL: no NSWorkspace (NSOpenURLsWithApplication) category in NSWorkspace.m; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fobjc-exceptions -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-unused-variable -DCATEGORY_INC="\"$temp/category.inc\"" \
    "${prefix_flags[@]}" "$root/tests/workspace-open-urls-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/open-urls"
"$temp/open-urls"
