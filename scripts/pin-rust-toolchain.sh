#!/usr/bin/env bash
#
# Pin cargokit's Rust toolchain for reproducible Rust-plugin builds (tor + openalias).
#
# cargokit hardcodes the toolchain to "stable" and runs `rustup run stable cargo ...`
# — a MOVING channel, so the plugin would be built with whatever stable is latest at
# build time (non-reproducible across time). The explicit `rustup run` also overrides
# both RUSTUP_TOOLCHAIN and the plugin's rust-toolchain.toml, so those pins don't take.
# cargokit's config only allows the channel enum (stable/beta/nightly), not an exact
# version — so we patch the default in the package instead.
#
# Two cargokit copies need patching, in different places:
#   - tor_ffi_plugin: a pub.dev/git dependency -> its cargokit lives in PUB_CACHE.
#   - openalias_ffi:  an in-repo PATH plugin   -> its cargokit lives in plugins/.
#
# Run AFTER `flutter pub get` (so the tor package is in PUB_CACHE) and BEFORE the
# flutter build. Idempotent; safe if the string is already pinned.
#
set -euo pipefail

TOOLCHAIN="${1:-1.96.1}"
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

n=0
while IFS= read -r f; do
  if grep -q "?? 'stable'" "$f"; then
    sed -i "s/?? 'stable'/?? '$TOOLCHAIN'/" "$f"
    n=$((n + 1))
  fi
done < <(find "$CACHE" "$ROOT/plugins" -path '*/cargokit/build_tool/lib/src/builder.dart' 2>/dev/null | sort -u)

echo "pin-rust-toolchain: set cargokit toolchain to $TOOLCHAIN in $n file(s) (PUB_CACHE=$CACHE, repo=$ROOT)"
[ "$n" -gt 0 ] || echo "  (warning: no cargokit builder.dart found/patched — verify PUB_CACHE + that the string still exists)"
