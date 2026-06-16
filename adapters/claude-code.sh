#!/usr/bin/env bash
# adapters/claude-code.sh — install skills/ contents into ~/.claude/skills/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

for skill in multica; do
  src="${REPO_ROOT}/skills/${skill}"
  if [[ ! -d "$src" ]]; then
    echo "[claude-code] WARN: missing source $src" >&2
    continue
  fi
  # symlink so updates flow through (idempotent)
  if [[ -L "${DEST}/${skill}" || -e "${DEST}/${skill}" ]]; then
    rm -rf "${DEST}/${skill}"
  fi
  ln -s "$src" "${DEST}/${skill}"
  echo "[claude-code] linked ${DEST}/${skill} → $src"
done
echo "[claude-code] Done. Restart Claude Code to pick up new skills."
