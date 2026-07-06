#!/usr/bin/env bash
#
# Pin cargokit's Rust toolchain for a reproducible tor_ffi_plugin build.
#
# cargokit (used by the tor plugin) hardcodes the toolchain to "stable" and runs
# `rustup run stable cargo ...` — a MOVING channel, so tor would be built with
# whatever stable is latest at build time (non-reproducible across time, and
# RUSTUP_TOOLCHAIN can't override an explicit `rustup run`). Its config only allows
# the channel enum (stable/beta/nightly), not an exact version — so we patch the
# default in the fetched package instead.
#
# Run AFTER `flutter pub get` (so the tor package is in PUB_CACHE) and BEFORE the
# flutter build. Idempotent; safe if the string is already pinned.
#
set -euo pipefail

TOOLCHAIN="${1:-1.96.1}"
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

n=0
while IFS= read -r f; do
  if grep -q "?? 'stable'" "$f"; then
    sed -i "s/?? 'stable'/?? '$TOOLCHAIN'/" "$f"
    n=$((n + 1))
  fi
done < <(find "$CACHE" -path '*/cargokit/build_tool/lib/src/builder.dart' 2>/dev/null)

echo "pin-tor-rust-toolchain: set cargokit toolchain to $TOOLCHAIN in $n file(s) (PUB_CACHE=$CACHE)"
[ "$n" -gt 0 ] || echo "  (warning: no cargokit builder.dart found/patched — verify PUB_CACHE + that the string still exists)"
