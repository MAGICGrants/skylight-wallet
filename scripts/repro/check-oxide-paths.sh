#!/usr/bin/env bash
#
# Release tripwire for the Monero library (libmonero_oxide_ffi.so).
#
# The library records absolute paths from the build machine: its Rust
# dependencies' sources in the cargo home (panic locations), and a file that a
# dependency's build script generates in the app's build directory. The
# library is otherwise byte-identical between builds, and the NDK's location
# does not reach it, so F-Droid's rebuild matches the release exactly when both
# build with the same cargo home and app path. This fails unless every APK's
# library names only those two places.
#
# Usage: scripts/repro/check-oxide-paths.sh <app-dir> <cargo-home> <apk>...
#   <app-dir>     the fixed build path the release and fdroid-build.sh share
#   <cargo-home>  the fixed CARGO_HOME they share
set -euo pipefail
export LC_ALL=C
usage='usage: scripts/repro/check-oxide-paths.sh <app-dir> <cargo-home> <apk>...'
app=${1:?$usage}
cargo=${2:?$usage}
shift 2
[ $# -gt 0 ] || { echo "$usage" >&2; exit 2; }
allowed_build="$app/build/"
allowed_cargo="$cargo/"
lib=$(mktemp)
trap 'rm -f "$lib"' EXIT
status=0
fail() { echo "$where: $1" >&2; status=1; }
for apk in "$@"; do
  entries=$(unzip -Z1 "$apk" 'lib/*/libmonero_oxide_ffi.so' 2>/dev/null || true)
  [ -n "$entries" ] || { where=$apk fail "no libmonero_oxide_ffi.so"; continue; }
  for entry in $entries; do
    where="$(basename "$apk") $entry"
    unzip -p "$apk" "$entry" > "$lib"
    # Any path from the build machine other than the two allowed: a home
    # directory, the SDK, a temporary or second build directory, or a default
    # cargo home.
    stray=$( (grep -a -o -E '/(root|home|Users|Volumes|tmp|opt|private/var|private/tmp|__w)/[!-~]{1,100}' "$lib"
      grep -a -o -E '[!-~]{0,40}\.cargo/registry/[!-~]{1,40}' "$lib") |
      awk -v b="$allowed_build" -v c="$allowed_cargo" 'index($0, b) != 1 && index($0, c) != 1' |
      sort -u || true)
    [ -z "$stray" ] || fail "names other build-machine paths: $(printf '%s\n' "$stray" | head -n 5)"
  done
done
[ $status -eq 0 ] && echo "Monero library names only $allowed_cargo and $allowed_build in: $*"
exit $status
