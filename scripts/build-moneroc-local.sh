#!/usr/bin/env bash
#
# Build the pinned monero_c Android .so in Docker with one command and install it
# into the app's jniLibs, so you can `flutter run`/build and test.
#
# Builds the exact monero_c the app is pinned to — the commit in pubspec.lock
# (magicgrants/monero_c fork, which carries the wrapper + Dart bindings and pins
# lwsf to magicgrants/lwsf). No source overlay: it clones and builds the fork as-is.
#
# Usage:
#   scripts/build-moneroc-local.sh [arch]
#     arch: aarch64-linux-android (default, arm64-v8a phones)
#           armv7a-linux-androideabi (armeabi-v7a)
#           x86_64-linux-android (x86_64 emulator)
#           all (build every arch)
#
# Env:
#   MONEROC_REF    monero_c commit to build (default: from pubspec.lock)
#   MONEROC_REPO   monero_c repo to clone (default: magicgrants fork)
#   BUILDER_IMAGE  base image (default: digest-pinned debian:bookworm, matches CI)
#
# Note: the first build is slow (compiles monero's `depends`: openssl, boost, ...);
# subsequent builds reuse the container's ccache only if you keep the image warm.
# The resulting .so lands in android/app/src/main/jniLibs/<abi>/ (root-owned).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${BUILDER_IMAGE:-debian:bookworm@sha256:30482e873082e906a4908c10529180aefb6f77620aea7404b909829fadc5d168}"
PATCH="$ROOT/scripts/reproducible.patch"
REPO="${MONEROC_REPO:-https://github.com/magicgrants/monero_c}"
REF="${MONEROC_REF:-$(awk '/^  monero:/{f=1} f&&/resolved-ref:/{gsub(/"/,"",$2);print $2;exit}' "$ROOT/pubspec.lock")}"

[ -f "$PATCH" ] || { echo "missing patch: $PATCH" >&2; exit 1; }
[ -n "$REF" ] || { echo "no monero resolved-ref in pubspec.lock" >&2; exit 1; }

case "${1:-aarch64-linux-android}" in
  all) ARCHS=(aarch64-linux-android armv7a-linux-androideabi x86_64-linux-android) ;;
  *)   ARCHS=("${1:-aarch64-linux-android}") ;;
esac

# Stream everything to the terminal AND save a log for review.
LOG="$ROOT/repro-out/build-local-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "==> logging to $LOG"

abi_for() {
  case "$1" in
    aarch64-linux-android)    echo arm64-v8a ;;
    armv7a-linux-androideabi) echo armeabi-v7a ;;
    x86_64-linux-android)     echo x86_64 ;;
    *) echo "unknown arch: $1" >&2; return 1 ;;
  esac
}

for ARCH in "${ARCHS[@]}"; do
  ABI="$(abi_for "$ARCH")"
  mkdir -p "$ROOT/android/app/src/main/jniLibs/$ABI"
  echo "==> building $ARCH  ->  jniLibs/$ABI/libmonero_libwallet2_api_c.so"
  echo "==> repo=$REPO ref=$REF"

  docker run --rm \
    -v "$PATCH:/patch/reproducible.patch:ro" \
    -v "$ROOT/android/app/src/main/jniLibs/$ABI:/out" \
    -e ARCH="$ARCH" -e REF="$REF" -e REPO="$REPO" \
    "$IMAGE" bash -euo pipefail -c '
      export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
      echo "==> [$ARCH] installing build toolchain (apt)..."
      apt-get update -qq
      apt-get install -y -q --no-install-recommends \
        apt-utils build-essential pkg-config autoconf libtool ccache make cmake gcc g++ git \
        curl lbzip2 gperf unzip python-is-python3 llvm ca-certificates
      git config --global --add safe.directory "*"
      git config --global user.email "local@repro"
      git config --global user.name "local repro"

      # Fixed canonical build path (depends bakes it into openssl/unbound).
      work=/tmp/monero_c
      rm -rf "$work"
      echo "==> [$ARCH] cloning $REPO @ $REF + submodules (a few minutes)..."
      git clone "$REPO" "$work"
      cd "$work"
      git fetch --quiet origin "$REF" || true
      git checkout --quiet "$REF"
      git submodule update --init --recursive --force

      # Deterministic version hash (git am committer date) as in the repro build.
      export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
      export GIT_COMMITTER_DATE="@$SOURCE_DATE_EPOCH"
      echo "==> [$ARCH] applying monero patches + reproducible.patch..."
      ./apply_patches.sh monero
      patch -p1 < /patch/reproducible.patch
      echo "==> [$ARCH] building (compiles depends: openssl/boost/... first — SLOW)..."
      ./build_single.sh monero "$ARCH" -j"$(nproc)"

      so="monero_libwallet2_api_c/build/$ARCH/libwallet2_api_c.so"
      strip=$(find "contrib/depends/$ARCH/native" -name llvm-strip 2>/dev/null | head -1)
      [ -n "$strip" ] || strip=$(command -v llvm-strip 2>/dev/null || true)
      if [ -n "$strip" ]; then
        "$strip" --strip-unneeded -o /out/libmonero_libwallet2_api_c.so "$so"
      else
        cp "$so" /out/libmonero_libwallet2_api_c.so
      fi
      sha256sum /out/libmonero_libwallet2_api_c.so
    '
  echo "==> installed jniLibs/$ABI/libmonero_libwallet2_api_c.so"
done

echo "==> done. Now rebuild the app:  flutter run   (or  flutter build apk)"
