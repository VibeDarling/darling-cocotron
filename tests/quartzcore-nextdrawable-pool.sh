#!/usr/bin/env bash
# Host model of the nextDrawable pool protocol; see the header of the C file.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
cc -Wall -Wextra "$root/tests/quartzcore-nextdrawable-pool.c" -o "$temp/probe"
"$temp/probe"
