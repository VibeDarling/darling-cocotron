#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Ancillary test tooling, GPL-3.0; the patched cocotron sources keep their own licence.
# Builds tests/appkit-range-entries.m with AppKit/NSTextView.subproj/AKRangeEntries.m against a
# Foundation (Apple's, or Darling's on a Darling guest) and runs it. Variables:
#   CC          compiler (default clang)
#   AK_LDFLAGS  link flags (default "-framework Foundation")
#   AK_RUNNER   command that runs the built binary, for cross builds (default none)
#   AK_SRC_DIR  directory holding AKRangeEntries.{h,m} (default: this checkout)
#   AK_MUTATE   merge | adjacent | atrange: run against a copy of the source with one rule broken, to show
#               the test can fail; the script then exits non-zero.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${AK_SRC_DIR:-$root/AppKit/NSTextView.subproj}
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

case "${AK_MUTATE:-}" in
"") ;;
merge)
    # equal values next to each other are no longer joined on insert
    mutation='s/\[\(id\)\(self->entries\[insertAt - 1\]\.value\) isEqual: value\]/NO/' ;;
adjacent)
    # equal values are joined even across a gap
    mutation='s/NSMaxRange\(self->entries\[insertAt - 1\]\.range\) ==\s+range\.location &&//' ;;
atrange)
    # the binary search of AKRangeEntryAtRange may step one slot past the table
    mutation='s/top = \(NSInteger\) self->count - 1;/top = self->count;/' ;;
*)
    echo "unknown AK_MUTATE value: $AK_MUTATE" >&2
    exit 2 ;;
esac
if [ -n "${AK_MUTATE:-}" ]; then
    mkdir "$temp/mutant"
    cp "$src/AKRangeEntries.h" "$temp/mutant/"
    perl -0pe "$mutation" "$src/AKRangeEntries.m" >"$temp/mutant/AKRangeEntries.m"
    if cmp -s "$src/AKRangeEntries.m" "$temp/mutant/AKRangeEntries.m"; then
        echo "mutation $AK_MUTATE did not change AKRangeEntries.m; update tests/appkit-range-entries.sh" >&2
        exit 2
    fi
    src=$temp/mutant
fi

# shellcheck disable=SC2086
${CC:-clang} -UNDEBUG -O0 -g -Wformat -Werror=format -I"$src" \
    "$root/tests/appkit-range-entries.m" "$src/AKRangeEntries.m" \
    -o "$temp/appkit-range-entries" ${AK_LDFLAGS--framework Foundation}
# shellcheck disable=SC2086
${AK_RUNNER:-} "$temp/appkit-range-entries"
