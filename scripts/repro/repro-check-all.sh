#!/usr/bin/env bash
#
# Run repro-check.sh for every Android ABI and print a summary.
# Continues past a failing arch so you get results for all three in one run.
#
# Usage: scripts/repro/repro-check-all.sh
#
# NOTE: 6 full monero_c builds total (2 per arch). Expect several hours.
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK="$ROOT/scripts/repro/repro-check.sh"

# Stream everything (this run + all per-arch child output) to one log on the fly.
if [ -z "${REPRO_LOG:-}" ]; then
  export REPRO_LOG="$ROOT/repro-out/repro-all-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$(dirname "$REPRO_LOG")"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  echo "==> logging to $REPRO_LOG"
fi

ARCHES=(
  aarch64-linux-android
  armv7a-linux-androideabi
  x86_64-linux-android
)

declare -A RESULT
rc=0

for arch in "${ARCHES[@]}"; do
  echo
  echo "########################################################"
  echo "# repro-check: $arch"
  echo "########################################################"
  if "$CHECK" "$arch"; then
    RESULT[$arch]="PASS ✅"
  else
    RESULT[$arch]="FAIL ❌"
    rc=1
  fi
done

echo
echo "================ SUMMARY ================"
for arch in "${ARCHES[@]}"; do
  printf '  %-28s %s\n' "$arch" "${RESULT[$arch]}"
done
echo "========================================"
exit "$rc"
