#!/usr/bin/env bash
#
# End-to-end reproducibility check using F-Droid's OWN buildserver container and the
# REAL recipe (fdroiddata/metadata/org.magicgrants.skylight.yml) — the authoritative
# RB environment (ANDROID_HOME=/opt/android-sdk, Debian trixie), unlike apk-repro-check
# which replicates recipe steps in the custom builder image.
#
# It builds the recipe TWICE in fresh containers and compares the UNSIGNED APKs
# (fdroid's build step emits unsigned APKs — no signature to strip).
#
# Because our changes aren't pushed, it builds from the CURRENT WORKING TREE via a
# throwaway commit, and temporarily points the recipe at the local repo. Everything
# is reverted on exit.
#
# Usage:
#   scripts/repro/fdroid-repro-check.sh [versioncode]
#     [versioncode] 4022 (arm64-v8a, default) | 4021 (armeabi-v7a) | 4023 (x86_64)
#
# Env:
#   RUNS=1   build once only (smoke-test the recipe; skip the repro comparison)
#
# NOTE: very heavy — each run does the full recipe (monero_c depends ~1h + flutter).
# Needs network. Mutates fdroiddata/{build,logs,unsigned,tmp} (gitignored artifacts).
#
set -euo pipefail

VC="${1:-4022}"
APPID="org.magicgrants.skylight"
IMAGE="registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FDD="$ROOT/fdroiddata"
RECIPE="$FDD/metadata/$APPID.yml"
OUT="$ROOT/repro-out/fdroid-$VC"
RUNS="${RUNS:-2}"
mkdir -p "$OUT"

command -v docker >/dev/null || { echo "docker required" >&2; exit 1; }
[ -f "$RECIPE" ] || { echo "recipe not found: $RECIPE" >&2; exit 1; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "pull first: docker pull $IMAGE" >&2; exit 1; }

# The buildserver's legacy sdkmanager is broken under JDK17, so we install the NDK
# from a cached zip (F-Droid's own provisioning method: unzip + rename by Pkg.Revision).
NDK_ZIP="$ROOT/repro-out/cache/android-ndk-r28b-linux.zip"   # r28b == 28.1.13356709
if [ ! -f "$NDK_ZIP" ]; then
  echo "==> caching NDK r28b…"; mkdir -p "$(dirname "$NDK_ZIP")"
  curl -fL --retry 2 -o "$NDK_ZIP" https://dl.google.com/android/repository/android-ndk-r28b-linux.zip
fi

if [ -z "${REPRO_LOG:-}" ]; then
  export REPRO_LOG="$ROOT/repro-out/fdroid-repro-$VC-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$REPRO_LOG")"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  echo "==> logging to $REPRO_LOG"
fi

cd "$ROOT"

# --- capture the working tree as a throwaway commit, reachable via a temp branch ---
# (fdroid clones the recipe's Repo@commit; a commit must be ref-reachable to be fetched)
RECIPE_BAK="$(mktemp)"; cp "$RECIPE" "$RECIPE_BAK"
CONFIG_BAK="$(mktemp)"; cp "$FDD/config.yml" "$CONFIG_BAK"
TMP_BRANCH="repro-test-$$"
cleanup() {
  echo "==> cleanup: restoring recipe + config + git state"
  cp "$RECIPE_BAK" "$RECIPE"; rm -f "$RECIPE_BAK"
  cp "$CONFIG_BAK" "$FDD/config.yml"; rm -f "$CONFIG_BAK"
  git reset -q                              # unstage
  git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

git add -u                                  # tracked modifications (pubspec, scripts, ...)
git add scripts/reproducible.patch scripts/pin-rust-toolchain.sh scripts/fdroid-build.sh scripts/build-moneroc.sh 2>/dev/null || true
TREE=$(git write-tree)
TMP_COMMIT=$(git commit-tree "$TREE" -p HEAD -m "repro test (throwaway)")
git branch -f "$TMP_BRANCH" "$TMP_COMMIT"
git reset -q                                # restore index; working tree untouched
echo "==> throwaway commit $TMP_COMMIT (branch $TMP_BRANCH)"

# --- temporarily point the recipe at the local repo + throwaway commit ---
sed -i "s|^Repo: .*|Repo: file:///apprepo|" "$RECIPE"
sed -i "s|commit: [0-9a-f]\{40\}|commit: $TMP_COMMIT|g" "$RECIPE"
echo "==> recipe Repo->file:///apprepo, commit->$TMP_COMMIT"

# --- tell fdroid where the NDK is (installed into the container below) ---
if ! grep -q '^ndk_paths:' "$FDD/config.yml"; then
  printf '\nndk_paths:\n  "28.1.13356709": /opt/android-sdk/ndk/28.1.13356709\n' >> "$FDD/config.yml"
  echo "==> added ndk_paths to config.yml"
fi

run_build() {
  local outname="$1"
  echo "===== fdroid build $APPID:$VC ($outname) ====="
  docker run --rm \
    -v "$ROOT:/apprepo:ro" \
    -v "$FDD:/fdroiddata" \
    -v "$(dirname "$NDK_ZIP"):/ndkcache:ro" \
    -e ANDROID_HOME=/opt/android-sdk -e ANDROID_SDK_ROOT=/opt/android-sdk \
    -w /fdroiddata \
    "$IMAGE" bash -euo pipefail -c '
      export DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes
      # buildserver image ships the env (SDK/gradle) but not fdroidserver itself.
      apt-get update -qq
      apt-get install -y -qq fdroidserver >/dev/null
      # the recipe sudo: deps (fdroid build skips sudo: outside server mode) — keep in sync with the recipe
      apt-get install -y -qq make libc-dev g++ rustup pkg-config autoconf automake libtool \
        ccache cmake lbzip2 gperf unzip llvm libssl-dev zlib1g-dev libncurses-dev xz-utils >/dev/null
      # install the pinned NDK from the cached zip (sdkmanager is broken under JDK17)
      if [ ! -d /opt/android-sdk/ndk/28.1.13356709 ]; then
        mkdir -p /opt/android-sdk/ndk
        unzip -q /ndkcache/android-ndk-r28b-linux.zip -d /opt/android-sdk/ndk
        mv /opt/android-sdk/ndk/android-ndk-r28b /opt/android-sdk/ndk/28.1.13356709
      fi
      test -d /opt/android-sdk/ndk/28.1.13356709 || { echo "NDK install failed"; exit 1; }
      git config --global --add safe.directory "*"
      rm -rf "build/'"$APPID"'" "unsigned/'"$APPID"'_'"$VC"'.apk"
      fdroid build --no-tarball "'"$APPID:$VC"'"
    '
  cp "$FDD/unsigned/${APPID}_${VC}.apk" "$OUT/$outname"
  echo "==> wrote $OUT/$outname"
}

run_build a.apk
if [ "$RUNS" = "1" ]; then
  echo "PASS (smoke): recipe built $APPID:$VC in the buildserver container -> $OUT/a.apk"
  exit 0
fi
run_build b.apk

# --- compare unsigned content (unzip per-file sha + zip structure) ---
echo
echo "=== whole-file sha256 ==="; sha256sum "$OUT/a.apk" "$OUT/b.apk"
EA=$(mktemp -d); EB=$(mktemp -d)
unzip -oq "$OUT/a.apk" -d "$EA"; unzip -oq "$OUT/b.apk" -d "$EB"
ENTRY_DIFF=$(diff <(cd "$EA" && find . -type f -exec sha256sum {} \; | sort -k2) \
                  <(cd "$EB" && find . -type f -exec sha256sum {} \; | sort -k2) || true)
STRUCT_DIFF=$(diff <(zipinfo "$OUT/a.apk" | sed 1d) <(zipinfo "$OUT/b.apk" | sed 1d) || true)
rm -rf "$EA" "$EB"

if [ -z "$ENTRY_DIFF" ] && [ -z "$STRUCT_DIFF" ]; then
  echo
  echo "PASS ✅  reproducible in the F-Droid buildserver for $APPID:$VC"
  exit 0
fi
echo
echo "FAIL ❌  differs:"
[ -n "$ENTRY_DIFF" ] && { echo "-- entries --"; echo "$ENTRY_DIFF" | grep -E '^[<>]' | awk '{print $2}' | sort -u; }
[ -n "$STRUCT_DIFF" ] && { echo "-- zip structure --"; echo "$STRUCT_DIFF" | head -20; }
echo "(APKs kept at $OUT/{a,b}.apk)"
exit 1
