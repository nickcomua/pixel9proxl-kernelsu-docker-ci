#!/usr/bin/env bash
set -euo pipefail

root="${1:-${KERNEL_WORKDIR:-work/caimito}}"

if [[ "${SKIP_SYNC:-0}" != "1" ]]; then
  ./scripts/sync-source.sh "$root"
fi

if [[ "${SKIP_PATCHES:-0}" != "1" ]]; then
  ./scripts/apply-patches.sh "$root"
fi

./scripts/build.sh "$root"
