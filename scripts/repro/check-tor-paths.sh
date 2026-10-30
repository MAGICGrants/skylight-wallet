#!/usr/bin/env bash
#
# Release tripwire for the Tor library (libtor_ffi_plugin.so).
#
# Tor's OpenSSL compiles in the absolute path of the NDK's clang ("compiler:")
# and the Flutter build hook's directory (ENGINESDIR, MODULESDIR), whose name
# is a hash of the hook's config, NDK paths included. F-Droid's rebuild can
# only match the release when both name the same NDK and the same app path, so
# this fails unless every APK's library names exactly those, no other absolute
# path, and no wall-clock build time.
#
# Usage: scripts/repro/check-tor-paths.sh <app-dir> <ndk-dir> <apk>...
#   <app-dir>  the fixed build path the release and fdroid-build.sh share
#   <ndk-dir>  the NDK the build hooks were given (ANDROID_NDK_HOME)
set -euo pipefail
export LC_ALL=C
usage='usage: scripts/repro/check-tor-paths.sh <app-dir> <ndk-dir> <apk>...'
app=${1:?$usage}
ndk=${2:?$usage}
shift 2
[ $# -gt 0 ] || { echo "$usage" >&2; exit 2; }
hook_dir="$app/.dart_tool/hooks_runner/shared/tor_ffi_plugin/build/"
# OpenSSL writes the build time as Perl's gmtime does: "Tue Oct  6 19:39:06 2026 UTC".
today=$(LC_ALL=C date -u '+%a %b %e')
lib=$(mktemp)
trap 'rm -f "$lib"' EXIT

status=0
fail() { echo "$where: $1" >&2; status=1; }
for apk in "$@"; do
  entries=$(unzip -Z1 "$apk" 'lib/*/libtor_ffi_plugin.so' 2>/dev/null || true)
  [ -n "$entries" ] || { where=$apk fail "no libtor_ffi_plugin.so"; continue; }
  for entry in $entries; do
    where="$(basename "$apk") $entry"
    unzip -p "$apk" "$entry" > "$lib"

    grep -a -q -F "compiler: $ndk/toolchains/" "$lib" ||
      fail "OpenSSL was not compiled with the NDK at $ndk"

    dirs=$(grep -a -o -E '(ENGINESDIR|MODULESDIR): "[^"]*"' "$lib" || true)
    [ -n "$dirs" ] || fail "no ENGINESDIR or MODULESDIR found"
    outside=$(printf '%s\n' "$dirs" | grep -v -F "\"$hook_dir" || true)
    [ -z "$outside" ] || fail "OpenSSL's module directories are outside $hook_dir: $outside"

    # Any other path from the build machine: a home directory (an unmapped
    # cargo home), the SDK, a temporary or second build directory. The
    # library's own constants (certificate and temp-file search paths such as
    # /etc/ssl or /var/tmp) are not of these forms.
    stray=$( (grep -a -o -E '/(root|home|Users|Volumes|tmp|opt/android-sdk|opt/cargo|private/var|private/tmp)/[!-~]{1,100}' "$lib"
      grep -a -o -E '[!-~]{0,40}\.cargo/registry/[!-~]{1,40}' "$lib") |
      grep -v -F -e "$ndk/toolchains/" -e "$hook_dir" | sort -u || true)
    [ -z "$stray" ] || fail "names other build-machine paths: $(printf '%s\n' "$stray" | head -n 5)"

    ! grep -a -q -F "built on: $today " "$lib" ||
      fail "OpenSSL recorded today's date as its build time"
  done
done
[ $status -eq 0 ] && echo "Tor library names only $ndk and $hook_dir in: $*"
exit $status
