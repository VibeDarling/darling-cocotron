#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Builds tests/appkit-cell-undo.m with AppKit/NSCellUndoManager.m (class renamed to
# AKTestCellUndoManager and its helper class AKCellUndoSentinel renamed as well, so neither clashes
# with the ones inside AppKit) against a Foundation and
# AppKit (NSDocument) and runs it. Variables:
#   CC          compiler (default clang)
#   AK_LDFLAGS  link flags (default "-framework Foundation -framework AppKit")
#   AK_RUNNER   command that runs the built binary, for cross builds (default none)
#   AK_SRC_DIR  directory holding NSCellUndoManager.{h,m} (default: AppKit/ of this checkout)
#   AK_MUTATE   noclear | keepaction: run against a copy of the source with one rule broken, to
#               show the test can fail; the script then exits non-zero.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${AK_SRC_DIR:-$root/AppKit}
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

case "${AK_MUTATE:-}" in
"") ;;
noclear)
    # the throwaway registration is never made, so the next manager keeps its redo stack
    mutation='s/\[next registerUndoWithTarget: sentinel selector: \@selector\(noop:\) object: nil\];//' ;;
keepaction)
    # the throwaway action is not taken back, so it stays on the next manager's undo stack
    mutation='s/\[next removeAllActionsWithTarget: sentinel\];//' ;;
*)
    echo "unknown AK_MUTATE value: $AK_MUTATE" >&2
    exit 2 ;;
esac
if [ -n "${AK_MUTATE:-}" ]; then
    mkdir "$temp/mutant"
    cp "$src/NSCellUndoManager.h" "$temp/mutant/"
    perl -0pe "$mutation" "$src/NSCellUndoManager.m" >"$temp/mutant/NSCellUndoManager.m"
    if cmp -s "$src/NSCellUndoManager.m" "$temp/mutant/NSCellUndoManager.m"; then
        echo "mutation $AK_MUTATE did not change NSCellUndoManager.m; update tests/appkit-cell-undo.sh" >&2
        exit 2
    fi
    src=$temp/mutant
fi

# shellcheck disable=SC2086
${CC:-clang} -UNDEBUG -O0 -g -Wformat -Werror=format -DNSCellUndoManager=AKTestCellUndoManager \
    -DAKCellUndoSentinel=AKTestCellUndoSentinel -I"$src" \
    "$root/tests/appkit-cell-undo.m" "$src/NSCellUndoManager.m" \
    -o "$temp/appkit-cell-undo" ${AK_LDFLAGS--framework Foundation -framework AppKit}
# shellcheck disable=SC2086
${AK_RUNNER:-} "$temp/appkit-cell-undo"
