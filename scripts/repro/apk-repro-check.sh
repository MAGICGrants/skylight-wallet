#!/usr/bin/env bash
#
# APK-level reproducibility check.
#
# Builds the release APK for one ABI TWICE at the FIXED canonical path /tmp/skylight
# (the path release.yml and the F-Droid recipe use) and compares them. Uses the
# repo's ALREADY-COMMITTED monero_c .so as a fixed input. Validates that the
# APK-layer build (Flutter AOT, tor + openalias Rust, dex, packaging) is deterministic
# at that path, using the SAME pinned cargokit toolchain as release.yml/recipe.
# NOTE: same-time builds share the pinned toolchain, so this proves the build is
# deterministic + openalias compiles — but only fdroid build --verify proves the pin
# holds across TIME. It also does NOT vary the Flutter SDK path (both builds use the image's
# /flutter) — a residual SDK-path leak would only surface in `fdroid build --verify`.
#
# Usage:
#   scripts/repro/apk-repro-check.sh [abi]
#     [abi] arm64-v8a (default) | armeabi-v7a | x86_64
#
# Env:
#   BUILDER_IMAGE   builder image with flutter+SDK+NDK+rust
#                   (default: ghcr.io/magicgrants/skylight-wallet-builder:latest)
#
# NOTE: ~2x flutter builds (~20-30 min each). Uses the CURRENT working tree
# (uncommitted changes included), copied clean into each build path. Needs network
# (pub + cargo crates for the tor plugin).
#
set -euo pipefail

ABI="${1:-arm64-v8a}"
case "$ABI" in
  arm64-v8a)    PLATFORM=android-arm64; RUST=aarch64-linux-android ;;
  armeabi-v7a)  PLATFORM=android-arm;   RUST=armv7-linux-androideabi ;;
  x86_64)       PLATFORM=android-x64;   RUST=x86_64-linux-android ;;
  *) echo "unknown abi: $ABI (use arm64-v8a|armeabi-v7a|x86_64)" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="${BUILDER_IMAGE:-ghcr.io/magicgrants/skylight-wallet-builder:latest}"
OUT="$ROOT/repro-out/apk-$ABI"
mkdir -p "$OUT"

SO="$ROOT/android/app/src/main/jniLibs/$ABI/libmonero_libwallet2_api_c.so"
[ -f "$SO" ] || { echo "committed .so not found: $SO" >&2; exit 1; }

if [ -z "${REPRO_LOG:-}" ]; then
  export REPRO_LOG="$ROOT/repro-out/apk-repro-$ABI-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$REPRO_LOG")"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  echo "==> logging to $REPRO_LOG"
fi

# Derive SOURCE_DATE_EPOCH on the host — the copied tree excludes .git (see copy_tree).
SDE=$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 1700000000)
echo "==> abi: $ABI | using committed .so | image: $IMAGE | SOURCE_DATE_EPOCH=$SDE"

docker run --rm \
  -v "$ROOT:/repo:ro" \
  -v "$OUT:/out" \
  -e ABI="$ABI" -e PLATFORM="$PLATFORM" -e RUST="$RUST" -e SOURCE_DATE_EPOCH="$SDE" \
  "$IMAGE" bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
    git config --global --add safe.directory "*"
    git config --global user.email "local@repro"
    git config --global user.name "local repro"

    # Copy the working tree WITHOUT the giant dirs the APK build never needs.
    # build/ alone is ~21G; cp -a of the whole 28G tree ran silent for minutes
    # and looked like a hang. .git is skipped too (SOURCE_DATE_EPOCH comes via -e).
    copy_tree() {
      local dst="$1"; mkdir -p "$dst"
      tar -C /repo \
        --exclude=./.git --exclude=./build --exclude=./fdroiddata \
        --exclude=./repro-out --exclude=./spice-wallet --exclude=./monero_c \
        --exclude=./.dart_tool --exclude=./.pub-cache \
        --exclude="./plugins/*/rust/target" \
        -cf - . | tar -C "$dst" -xpf -
    }

    build_app() {
      local app="$1" out="$2"
      echo "===== flutter build apk in $app ====="
      rm -rf "$app"
      echo "==> [$app] copying working tree (excludes build/fdroiddata/.git/...)..."
      copy_tree "$app"
      cd "$app"
      test -f "android/app/src/main/jniLibs/$ABI/libmonero_libwallet2_api_c.so"
      : "${SOURCE_DATE_EPOCH:=1700000000}"   # from host -e (.git not copied)
      rustup default 1.83.0 >/dev/null 2>&1 || true
      rustup target add "$RUST" >/dev/null 2>&1 || true
      export PUB_CACHE="$app/.pub-cache"
      echo "==> [$app] flutter pub get..."
      flutter pub get --enforce-lockfile
      echo "==> [$app] pinning cargokit toolchain (tor + openalias)..."
      bash scripts/pin-rust-toolchain.sh
      echo "==> [$app] flutter build apk (Rust + Dart AOT; slow, limited output)..."
      flutter build apk --dart-define=DEMO_MODE=true --release --split-per-abi --target-platform="$PLATFORM"
      cp "build/app/outputs/flutter-apk/app-$ABI-release.apk" "/out/$out"
    }

    # Two builds at the FIXED canonical path (/tmp/skylight) used by release.yml and
    # the recipe. Validates the build is deterministic there. (An earlier different-path
    # run proved the leak; Flutter AOT cannot be path-remapped, so we fix the path.)
    build_app /tmp/skylight a.apk
    build_app /tmp/skylight b.apk

    echo "===== in-container sha256 ====="
    sha256sum /out/a.apk /out/b.apk
  '

echo
echo "=== whole-APK sha256 (includes signature — expected to differ) ==="
sha256sum "$OUT/a.apk" "$OUT/b.apk"

# F-Droid ignores the signature (apksigcopier strips it, then attaches the
# developer's published signature). So the reproducibility criterion is the
# UNSIGNED content: every zip entry + the central directory (zipinfo). A diff
# confined to the APK Signing Block is expected and irrelevant.
EA=$(mktemp -d); EB=$(mktemp -d)
trap 'rm -rf "$EA" "$EB"' EXIT
unzip -oq "$OUT/a.apk" -d "$EA"; unzip -oq "$OUT/b.apk" -d "$EB"
ENTRY_DIFF=$(diff <(cd "$EA" && find . -type f -exec sha256sum {} \; | sort -k2) \
                  <(cd "$EB" && find . -type f -exec sha256sum {} \; | sort -k2) || true)
STRUCT_DIFF=$(diff <(zipinfo "$OUT/a.apk" | sed 1d) <(zipinfo "$OUT/b.apk" | sed 1d) || true)

if [ -z "$ENTRY_DIFF" ] && [ -z "$STRUCT_DIFF" ]; then
  echo
  echo "PASS ✅  unsigned APK content identical for $ABI"
  echo "         (only the signature differs — F-Droid strips + replaces it)"
  exit 0
fi

echo
echo "FAIL ❌  unsigned content differs for $ABI:"
if [ -n "$ENTRY_DIFF" ]; then
  echo "-- entries that differ --"
  echo "$ENTRY_DIFF" | grep -E '^[<>]' | awk '{print $2}' | sort -u
fi
if [ -n "$STRUCT_DIFF" ]; then
  echo "-- zip structure (zipinfo) diff, first 20 --"
  echo "$STRUCT_DIFF" | head -20
fi
echo "(APKs kept at $OUT/{a,b}.apk)"
exit 1
