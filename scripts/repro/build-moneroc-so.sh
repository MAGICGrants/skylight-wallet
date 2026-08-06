#!/usr/bin/env bash
#
# Build the monero_c Android .so locally in a debian:bookworm container
# (mirrors .github/workflows/build-monero-c.yml), with scripts/reproducible.patch
# applied — same as CI and the F-Droid recipe.
#
# Usage:
#   scripts/repro/build-moneroc-so.sh <arch> [outdir]
#     <arch>   one of: aarch64-linux-android | armv7a-linux-androideabi | x86_64-linux-android
#     [outdir] where to drop the .so (default: repro-out/<arch>)
#
# Builds at a FIXED canonical path (/tmp/monero_c). depends bakes its prefix
# (openssl OPENSSLDIR etc.) into the libs, so the build dir must be identical
# everywhere — CI and the F-Droid recipe must build at this same path too.
#
# Env:
#   MONEROC_REF     monero_c commit to build (default: extracted from pubspec.lock)
#   BUILDER_IMAGE   base image (default: digest-pinned debian:bookworm, matches CI)
#   INSTALL=1       also copy the .so into android/app/src/main/jniLibs/<abi>/
#
set -euo pipefail

ARCH="${1:?usage: build-moneroc-so.sh <arch> [outdir]}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${2:-$ROOT/repro-out/$ARCH}"
REF="${MONEROC_REF:-$(awk '/^  monero:/{f=1} f&&/resolved-ref:/{gsub(/"/,"",$2);print $2;exit}' "$ROOT/pubspec.lock")}"
IMAGE="${BUILDER_IMAGE:-debian:bookworm@sha256:30482e873082e906a4908c10529180aefb6f77620aea7404b909829fadc5d168}"
PATCH="$ROOT/scripts/reproducible.patch"

case "$ARCH" in
  aarch64-linux-android)       ABI=arm64-v8a ;;
  armv7a-linux-androideabi)    ABI=armeabi-v7a ;;
  x86_64-linux-android)        ABI=x86_64 ;;
  *) echo "unknown arch: $ARCH" >&2; exit 2 ;;
esac

[ -f "$PATCH" ] || { echo "missing patch: $PATCH" >&2; exit 1; }
mkdir -p "$OUT"

# Stream output to a log on the fly. If a caller already set REPRO_LOG, reuse it.
if [ -z "${REPRO_LOG:-}" ]; then
  export REPRO_LOG="$ROOT/repro-out/build-$ARCH-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$REPRO_LOG")"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  echo "==> logging to $REPRO_LOG"
fi

echo "==> building $ARCH (ref=$REF) in $IMAGE"

docker run --rm \
  -v "$PATCH:/patch/reproducible.patch:ro" \
  -v "$OUT:/out" \
  -e ARCH="$ARCH" -e REF="$REF" \
  "$IMAGE" bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
      apt-utils build-essential pkg-config autoconf libtool ccache make cmake gcc g++ git \
      curl lbzip2 gperf unzip python-is-python3 llvm ca-certificates >/dev/null
    git config --global --add safe.directory "*"
    git config --global user.email "local@repro"
    git config --global user.name "local repro"

    # Fixed canonical build path: depends bakes this into openssl/unbound, so it
    # must be identical across all builds (here, CI, and the F-Droid recipe).
    work="/tmp/monero_c"
    rm -rf "$work"
    git clone --quiet https://github.com/magicgrants/monero_c.git "$work"
    cd "$work"
    git checkout --quiet "$REF"
    git submodule update --init --recursive --force --quiet
    # Pin timestamps BEFORE patching. apply_patches.sh runs `git am`, whose commit
    # SHA depends on the committer date; Monero bakes that short-hash into its
    # version string (0.18.4.0-<hash>). Fix the date so the hash is deterministic.
    export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
    export GIT_COMMITTER_DATE="@$SOURCE_DATE_EPOCH"
    echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
    ./apply_patches.sh monero
    patch -p1 < /patch/reproducible.patch
    ./build_single.sh monero "$ARCH" -j"$(nproc)"

    so="monero_libwallet2_api_c/build/$ARCH/libwallet2_api_c.so"
    cp "$so" /out/libwallet2_api_c.so
    # Strip like AGP does before packaging — this is what actually ships in the APK.
    strip=$(find "contrib/depends/$ARCH/native" -name llvm-strip 2>/dev/null | head -1)
    [ -n "$strip" ] || strip=$(command -v llvm-strip 2>/dev/null || true)
    if [ -n "$strip" ]; then
      "$strip" --strip-unneeded -o /out/libwallet2_api_c.stripped.so /out/libwallet2_api_c.so
    else
      echo "WARN: no llvm-strip found; stripped == unstripped" >&2
      cp /out/libwallet2_api_c.so /out/libwallet2_api_c.stripped.so
    fi
    sha256sum /out/libwallet2_api_c.so /out/libwallet2_api_c.stripped.so
  '

echo "==> wrote $OUT/libwallet2_api_c.so"

if [ "${INSTALL:-}" = "1" ]; then
  dest="$ROOT/android/app/src/main/jniLibs/$ABI/libmonero_libwallet2_api_c.so"
  mkdir -p "$(dirname "$dest")"
  cp "$OUT/libwallet2_api_c.so" "$dest"
  echo "==> installed -> $dest"
fi
