#!/usr/bin/env bash
#
# Reproducibility check for the monero_c .so.
# Builds the SAME source TWICE (two independent containers, same fixed canonical
# path) and compares. Identical => the build is deterministic at that path, which
# is what CI and the F-Droid recipe rely on (they build at the same fixed path).
#
# Usage:
#   scripts/repro/repro-check.sh [arch]
#     [arch] default: aarch64-linux-android
#
# NOTE: each build compiles the full depends tree (boost, openssl, monero...) from
# scratch — expect ~30-90 min PER build, so ~1-3h total. Containers are ephemeral
# so no state leaks between the two runs.
#
set -euo pipefail

ARCH="${1:-aarch64-linux-android}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/scripts/repro/build-moneroc-so.sh"

# Stream output to a log on the fly. If a caller already set REPRO_LOG, reuse it.
if [ -z "${REPRO_LOG:-}" ]; then
  export REPRO_LOG="$ROOT/repro-out/repro-check-$ARCH-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$REPRO_LOG")"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  echo "==> logging to $REPRO_LOG"
fi

# Single source of truth: the monero_c commit pinned in pubspec.lock.
export MONEROC_REF="${MONEROC_REF:-$(awk '/^  monero:/{f=1} f&&/resolved-ref:/{gsub(/"/,"",$2);print $2;exit}' "$ROOT/pubspec.lock")}"
echo "==> monero_c commit (from pubspec.lock): $MONEROC_REF"

# Kept on failure for inspection (removed only on PASS).
A="$(mktemp -d)"; B="$(mktemp -d)"

# Two independent builds (ephemeral containers, same fixed canonical path, same commit).
"$BUILD" "$ARCH" "$A"
"$BUILD" "$ARCH" "$B"

SA="$A/libwallet2_api_c.stripped.so"; SB="$B/libwallet2_api_c.stripped.so"
UA="$A/libwallet2_api_c.so";          UB="$B/libwallet2_api_c.so"

echo
echo "=== sha256 (stripped — what ships in the APK) ==="
sha256sum "$SA" "$SB"
echo "=== sha256 (unstripped — reference) ==="
sha256sum "$UA" "$UB"

if cmp -s "$SA" "$SB"; then
  echo
  echo "PASS ✅  stripped .so byte-identical — reproducible for $ARCH"
  rm -rf "$A" "$B"
  exit 0
fi

echo
echo "FAIL ❌  stripped .so differ. Diagnosing (readelf/strings — arch-agnostic)..."

# 1) Which sections changed size? Localizes the diff (.rodata vs .data.rel.ro vs .text).
echo "=== section-size diff (readelf -S) ==="
diff <(readelf -SW "$SA" | awk '{print $2, $6}') \
     <(readelf -SW "$SB" | awk '{print $2, $6}') || echo "(section sizes identical -> pure reordering, not resizing)"

# 2) Content strings that differ (added/removed). Reveals a varying path/temp/seed string.
echo "=== string content diff (sorted, unique; first 60) ==="
if diff <(strings -a "$UA" | sort -u) <(strings -a "$UB" | sort -u) | grep -E '^[<>]' | head -60; then :; else
  echo "(no string content differences -> data is identical but REORDERED)"
fi

# 3) Optional full byte diff.
if command -v diffoscope >/dev/null 2>&1; then
  DIFF="$ROOT/repro-out/diff-$ARCH-$(date +%Y%m%d-%H%M%S).txt"
  diffoscope --max-report-size 2000000 --text "$DIFF" "$SA" "$SB" >/dev/null 2>&1 || true
  echo "diffoscope report -> $DIFF"
fi

echo
echo "build outputs kept for inspection (rm when done):"
echo "  A: $A"
echo "  B: $B"
exit 1
