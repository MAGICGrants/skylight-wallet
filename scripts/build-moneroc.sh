#!/usr/bin/env bash
#
# Build monero_c's wallet2_api_c library for one target, at a FIXED path:
# /tmp/monero_c, or ~/Library/Caches/monero_c on macOS. Not /tmp there: CMake
# always rewrites /private/tmp (the real path) to /tmp, so depends' staging
# paths stop matching and the first package fails to install.
#
# Args:
#   $1  target (e.g. aarch64-linux-android, x86_64-linux-gnu, x86_64-w64-mingw32,
#       aarch64-apple-darwin)
#   $2  clone source (default: the local ./monero_c submodule; CI passes the remote URL)
#
# Run from the app repo root (needs pubspec.lock + scripts/reproducible.patch).
# Output: <path>/monero_libwallet2_api_c/build/<target>/libwallet2_api_c.{so,dll,dylib}
#
# macOS (on a Mac with Xcode, plus autoconf, automake, libtool, pkg-config and
# xz): the app loads it from macos/Frameworks/monero_libwallet2_api_c.dylib,
# copied there with `install_name_tool -id @rpath/monero_libwallet2_api_c.dylib`.
# Apple silicon only; the macOS apps exclude x86_64.
#
set -euo pipefail

TARGET="${1:?usage: build-moneroc.sh <target> [clone-source]}"
SRC="${2:-monero_c}"
REPO="$(pwd)"
COMMIT=$(awk '/^  monero:/{f=1} f&&/resolved-ref:/{gsub(/"/,"",$2);print $2;exit}' pubspec.lock)
[ -n "$COMMIT" ] || { echo "no monero resolved-ref in pubspec.lock" >&2; exit 1; }

# never create $HOME/.gitconfig (fdroiddata CI symlinks it per build)
export GIT_CONFIG_GLOBAL=/tmp/skylight-gitconfig
git config --global --add safe.directory '*'
git config --global user.name 'MAGIC Grants'
git config --global user.email 'info@magicgrants.org'

if [ "$(uname)" = Darwin ]; then
  BUILD_DIR="$HOME/Library/Caches/monero_c"
  JOBS="$(sysctl -n hw.logicalcpu)"
else
  BUILD_DIR=/tmp/monero_c
  JOBS="$(nproc)"
fi

rm -rf "$BUILD_DIR"
git clone "$SRC" "$BUILD_DIR"
git -C "$BUILD_DIR" checkout "$COMMIT"
# Only the submodules a Monero build uses; the others are for other coins,
# and fetching them fails the build whenever one of their hosts is down.
git -C "$BUILD_DIR" submodule update --init --recursive --force -- monero lwsf

cd "$BUILD_DIR"
# Pin the git-am committer date (baked into Monero's version string) + __DATE__/__TIME__.
export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
export GIT_COMMITTER_DATE="@$SOURCE_DATE_EPOCH"
./apply_patches.sh monero
patch -p1 < "$REPO/scripts/reproducible.patch"
unset MAKEFLAGS   # use make's classic pipe jobserver (from reproducible.patch), not the fifo one
./build_single.sh monero "$TARGET" -j"$JOBS"
