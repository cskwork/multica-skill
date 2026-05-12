#!/usr/bin/env bash
# adapters/opencode.sh — install skills into ~/.config/opencode/skills/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HOME}/.config/opencode/skills"
CMD_DEST="${HOME}/.config/opencode/commands"
mkdir -p "$DEST" "$CMD_DEST"

for skill in multica multica-workflow multica-onboarding; do
  src="${REPO_ROOT}/skills/${skill}"
  if [[ ! -d "$src" ]]; then continue; fi
  rm -rf "${DEST}/${skill}"
  ln -s "$src" "${DEST}/${skill}"
  cp "${src}/SKILL.md" "${CMD_DEST}/${skill}.md"
  echo "[opencode] installed ${skill}"
done

echo "[opencode] Done."
