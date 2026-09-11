#!/usr/bin/env bash
#
# Regenerate a git-pinned pubspec.lock — the form CI / F-Droid build against.
#
# Dev uses pubspec_overrides.yaml to point the wallet-core packages at the local
# ../wallet-core clone, which makes `flutter pub get` write `path:` deps into the
# lock. Committing that breaks the SHA-pinned release build. This temporarily
# removes the override, resolves against the git SHAs in pubspec.yaml, then puts
# the override back — leaving pubspec.lock git-pinned for you to commit.
#
# Usage:  bash scripts/regen-lockfile.sh
# Then:   git add pubspec.lock && git commit   (before your next `flutter pub get`)
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f pubspec.yaml ] || { echo "run from the app repo (no pubspec.yaml here)" >&2; exit 1; }

OVERRIDE=pubspec_overrides.yaml
STASH=.pubspec_overrides.yaml.regen-bak

# Restore the override no matter how we exit (pub get failure, Ctrl-C, ...).
restore() { [ -f "$STASH" ] && mv -f "$STASH" "$OVERRIDE"; }
trap restore EXIT

if [ -f "$OVERRIDE" ]; then
  mv -f "$OVERRIDE" "$STASH"
  echo "==> $OVERRIDE moved aside; resolving against the git SHAs in pubspec.yaml"
else
  echo "==> no $OVERRIDE present; resolving pubspec.yaml as-is"
fi

flutter pub get

echo
echo "==> pubspec.lock is now git-pinned. Commit it BEFORE your next 'flutter pub get':"
echo "      git add pubspec.lock && git commit -m 'Update pubspec.lock'"
echo "    then run 'flutter pub get' to restore your local ../wallet-core setup."
