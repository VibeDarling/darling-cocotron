#!/usr/bin/env bash
# Fail if an @implementation declares instance variables in a "{ ... }" block.
# Darling builds its frameworks fat, and the i386 slice uses the fragile
# Objective-C ABI, which rejects ivars in @implementation ("inconsistent number
# of instance variables"). Declare them in the @interface instead.
# Usage: check-implementation-ivars.sh [file...]   (default: every tracked .m/.mm)
set -euo pipefail

cd "$(dirname "$0")/.."
if [ "$#" -gt 0 ]; then
	files=("$@")
else
	files=()
	while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.m' '*.mm')
fi
[ "${#files[@]}" -gt 0 ] || exit 0

awk '
FNR == 1 { incomment = 0; pending = 0 }
{
	line = $0
	out = ""
	while (length(line) > 0) {
		if (incomment) {
			i = index(line, "*/")
			if (!i) { line = ""; break }
			line = substr(line, i + 2); incomment = 0
		} else {
			c = index(line, "/*"); s = index(line, "//")
			if (s && (!c || s < c)) { out = out substr(line, 1, s - 1); line = ""; break }
			if (!c) { out = out line; line = ""; break }
			out = out substr(line, 1, c - 1); line = substr(line, c + 2); incomment = 1
		}
	}
	if (out ~ /^[ \t]*$/) next
	if (pending) {
		if (out ~ /^[ \t]*\{/) { print FILENAME ":" pendingline; bad = 1 }
		pending = 0
	}
	if (out ~ /^[ \t]*@implementation[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*(\{[ \t]*)?$/) {
		if (out ~ /\{[ \t]*$/) { print FILENAME ":" FNR; bad = 1 }
		else { pending = 1; pendingline = FNR }
	}
}
END { exit bad }
' "${files[@]}" || { echo "error: ivars declared in @implementation (breaks the i386 fragile-ABI slice); move them to the @interface" >&2; exit 1; }
