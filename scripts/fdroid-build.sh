#!/usr/bin/env bash
#
# Reproducible F-Droid build of one ABI. Invoked from the recipe's build: step as:
#   - bash scripts/fdroid-build.sh <abi> $$flutter$$
# where fdroidserver substitutes $$flutter$$ with the flutter srclib path.
#
# Also usable by the upstream release CI (pass the flutter SDK path as $2).
#
# What it does (all deterministic):
#   - builds the Flutter app at a FIXED path (/tmp/skylight), with a fixed cargo
#     home (/tmp/skylight-cargo) and pub cache (/tmp/skylight/.pub-cache), so the
#     paths AOT, Tor, zxing and the Rust libraries record match release.yml's
#   - builds the Rust libraries (wallet_monero_oxide, the Monero wallet library,
#     and wallet_openalias) through cargokit with the rust-toolchain.toml
#     toolchain and their committed Cargo.lock (scripts/pin-rust-toolchain.sh)
#   - copies the APK back for fdroid's output:
#
set -euo pipefail

ABI="${1:?usage: fdroid-build.sh <abi> <flutter-sdk-path>}"
FLUTTER="${2:?flutter SDK path (\$\$flutter\$\$)}"
case "$ABI" in
  armeabi-v7a) PLATFORM=android-arm;   RUST=armv7-linux-androideabi ;;
  arm64-v8a)   PLATFORM=android-arm64; RUST=aarch64-linux-android ;;
  x86_64)      PLATFORM=android-x64;   RUST=x86_64-linux-android ;;
  *) echo "unknown abi: $ABI" >&2; exit 2 ;;
esac

REPO="$(pwd)"
NDK=28.1.13356709
FLUTTER_VERSION=$(grep -E '^\s+flutter:\s+' pubspec.yaml | head -1 | sed 's/.*flutter:\s*//')
[ -n "$FLUTTER_VERSION" ] || { echo "could not read flutter version from pubspec.yaml" >&2; exit 1; }

# never create $HOME/.gitconfig (fdroiddata CI symlinks it per build)
export GIT_CONFIG_GLOBAL=/tmp/skylight-gitconfig
git config --global --add safe.directory '*'
git config --global user.name 'MAGIC Grants'
git config --global user.email 'info@magicgrants.org'

# Flutter SDK pinned to the pubspec version.
git -C "$FLUTTER" checkout -f "$FLUTTER_VERSION"
"$FLUTTER/bin/flutter" config --no-analytics

# 1) Flutter app at a FIXED path (AOT, Tor, zxing and the Rust libraries record
#    the build dir, so it must be identical).
rm -rf /tmp/skylight
cp -a "$REPO" /tmp/skylight
rm -rf /tmp/skylight/build /tmp/skylight/.dart_tool
cd /tmp/skylight
# Keep fdroid's inherited SOURCE_DATE_EPOCH; /tmp/skylight has no .git so git log
# here would blank it, making OpenSSL bake the wall-clock time (non-reproducible).
: "${SOURCE_DATE_EPOCH:=$(git -C "$REPO" log -1 --format=%ct 2>/dev/null)}"
[ -n "$SOURCE_DATE_EPOCH" ] || { echo "SOURCE_DATE_EPOCH empty; refusing non-reproducible build" >&2; exit 1; }
export SOURCE_DATE_EPOCH
RUST_TOOLCHAIN=$(sed -n 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' rust-toolchain.toml | head -1)
rustup default "$RUST_TOOLCHAIN"
rustup target add "$RUST"
export PUB_CACHE=/tmp/skylight/.pub-cache
export CARGO_HOME=/tmp/skylight-cargo
# cargokit requires an NDK package.xml (absent in unzipped NDKs)
[ -f "$ANDROID_HOME/ndk/$NDK/package.xml" ] || touch "$ANDROID_HOME/ndk/$NDK/package.xml"
# Flutter's build hooks (Tor) take the NDK from ANDROID_NDK_HOME, else the
# newest one installed, and Tor's OpenSSL records its path; fdroidserver sets
# it from the recipe's ndk:, and release.yml sets the same NDK and path.
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK"
"$FLUTTER/bin/flutter" pub get --offline --enforce-lockfile
bash scripts/pin-rust-toolchain.sh
"$FLUTTER/bin/flutter" build apk --dart-define=DEMO_MODE=true --release --split-per-abi --target-platform="$PLATFORM"

# 2) Hand the APK to the builddir where fdroid's output: expects it.
mkdir -p "$REPO/build/app/outputs/flutter-apk"
cp "/tmp/skylight/build/app/outputs/flutter-apk/app-$ABI-release.apk" \
   "$REPO/build/app/outputs/flutter-apk/app-$ABI-release.apk"
