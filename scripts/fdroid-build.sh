#!/usr/bin/env bash
#
# Reproducible F-Droid build of one ABI. Invoked from the recipe's build: step as:
#   - bash scripts/fdroid-build.sh <abi> $$flutter$$
# where fdroidserver substitutes $$flutter$$ with the flutter srclib path.
#
# Also usable by the upstream release CI (pass the flutter SDK path as $2).
#
# What it does (all deterministic):
#   - builds monero_c at a FIXED path (/tmp/monero_c) so openssl's baked prefix matches
#   - pins the git-am committer date (Monero version hash) via GIT_COMMITTER_DATE
#   - builds the Flutter app at a FIXED path (/tmp/skylight) so AOT/tor/zxing don't
#     bake the build dir in; copies the APK back for fdroid's output:
#
set -euo pipefail

ABI="${1:?usage: fdroid-build.sh <abi> <flutter-sdk-path>}"
FLUTTER="${2:?flutter SDK path (\$\$flutter\$\$)}"
case "$ABI" in
  armeabi-v7a) ARCH=armv7a-linux-androideabi; PLATFORM=android-arm;   RUST=armv7-linux-androideabi ;;
  arm64-v8a)   ARCH=aarch64-linux-android;    PLATFORM=android-arm64; RUST=aarch64-linux-android ;;
  x86_64)      ARCH=x86_64-linux-android;     PLATFORM=android-x64;   RUST=x86_64-linux-android ;;
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

# 1) monero_c .so at a FIXED path — shared with CI so the committed .so matches this rebuild.
bash scripts/build-moneroc.sh "$ARCH"

# 2) Flutter app at a FIXED path (AOT/tor/zxing bake the build dir -> must be identical).
rm -rf /tmp/skylight
cp -a "$REPO" /tmp/skylight
rm -rf /tmp/skylight/build /tmp/skylight/.dart_tool /tmp/skylight/.pub-cache
mkdir -p "/tmp/skylight/android/app/src/main/jniLibs/$ABI"
cp "/tmp/monero_c/monero_libwallet2_api_c/build/$ARCH/libwallet2_api_c.so" \
   "/tmp/skylight/android/app/src/main/jniLibs/$ABI/libmonero_libwallet2_api_c.so"
rm -rf /tmp/monero_c
cd /tmp/skylight
export SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
rustup default 1.83.0
rustup target add "$RUST"
export PUB_CACHE=/tmp/skylight/.pub-cache
export CARGO_HOME=/tmp/skylight-cargo
# cargokit requires an NDK package.xml (absent in unzipped NDKs)
[ -f "$ANDROID_HOME/ndk/$NDK/package.xml" ] || touch "$ANDROID_HOME/ndk/$NDK/package.xml"
"$FLUTTER/bin/flutter" pub get
bash scripts/pin-tor-rust-toolchain.sh
"$FLUTTER/bin/flutter" build apk --dart-define=DEMO_MODE=true --release --split-per-abi --target-platform="$PLATFORM"

# 3) Hand the APK to the builddir where fdroid's output: expects it.
mkdir -p "$REPO/build/app/outputs/flutter-apk"
cp "/tmp/skylight/build/app/outputs/flutter-apk/app-$ABI-release.apk" \
   "$REPO/build/app/outputs/flutter-apk/app-$ABI-release.apk"
