#!/usr/bin/env bash
# adapters/pi.sh — install skills into ~/.pi/skills/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HOME}/.pi/skills"
mkdir -p "$DEST"

for skill in multica multica-workflow multica-onboarding; do
  src="${REPO_ROOT}/skills/${skill}"
  if [[ ! -d "$src" ]]; then continue; fi
  rm -rf "${DEST}/${skill}"
  ln -s "$src" "${DEST}/${skill}"
  echo "[pi] linked ${DEST}/${skill}"
done

echo "[pi] Done."
