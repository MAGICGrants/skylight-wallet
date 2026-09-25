#!/usr/bin/env bash
#
# F-Droid prebuild step: fetch pub dependencies into an in-tree PUB_CACHE so it
# can be scanned before fdroid-build.sh resolves against it offline.
#   - bash scripts/fdroid-prebuild.sh $$flutter$$
set -euo pipefail

FLUTTER="${1:?usage: fdroid-prebuild.sh <flutter-sdk-path>}"

FLUTTER_VERSION=$(grep -E '^\s+flutter:\s+' pubspec.yaml | head -1 | sed 's/.*flutter:\s*//')
[ -n "$FLUTTER_VERSION" ] || { echo "could not read flutter version from pubspec.yaml" >&2; exit 1; }

# never create $HOME/.gitconfig (fdroiddata CI symlinks it per build)
export GIT_CONFIG_GLOBAL=/tmp/skylight-gitconfig
git config --global --add safe.directory '*'
git config --global user.name 'MAGIC Grants'
git config --global user.email 'info@magicgrants.org'

git -C "$FLUTTER" checkout -f "$FLUTTER_VERSION"
"$FLUTTER/bin/flutter" config --no-analytics

export PUB_CACHE="${PUB_CACHE:-$(pwd)/.pub-cache}"
"$FLUTTER/bin/flutter" pub get --enforce-lockfile
