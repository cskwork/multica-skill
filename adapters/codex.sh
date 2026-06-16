#!/usr/bin/env bash
# adapters/codex.sh — install skills as both ~/.codex/skills/<name>/SKILL.md
# and ~/.codex/commands/<name>.md slash commands.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DEST="${HOME}/.codex/skills"
CMD_DEST="${HOME}/.codex/commands"
mkdir -p "$SKILL_DEST" "$CMD_DEST"

for skill in multica; do
  src="${REPO_ROOT}/skills/${skill}"
  if [[ ! -d "$src" ]]; then continue; fi

  # 1. Skill bundle (full directory, symlinked)
  rm -rf "${SKILL_DEST}/${skill}"
  ln -s "$src" "${SKILL_DEST}/${skill}"
  echo "[codex] linked ${SKILL_DEST}/${skill}"

  # 2. Slash command — Codex reads .md from ~/.codex/commands/
  cp "${src}/SKILL.md" "${CMD_DEST}/${skill}.md"
  echo "[codex] copied ${CMD_DEST}/${skill}.md"
done

echo "[codex] Done. Use /multica in Codex."
