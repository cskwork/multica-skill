#!/usr/bin/env bash
# adapters/gemini.sh — install skills as Gemini extensions / GEMINI.md commands.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT_DEST="${HOME}/.gemini/extensions"
SKILL_DEST="${HOME}/.gemini/skills"

# Tolerate the case where a previous tool left a broken symlink at SKILL_DEST.
ensure_dir() {
  local d="$1"
  if [[ -L "$d" && ! -e "$d" ]]; then
    echo "[gemini] WARN: $d is a broken symlink; will not overwrite. Remove it manually if you want gemini to read skills from here." >&2
    return 1
  fi
  mkdir -p "$d" 2>/dev/null || {
    echo "[gemini] WARN: could not create $d (skipping)" >&2
    return 1
  }
}
ensure_dir "$EXT_DEST"   || EXT_DEST=""
ensure_dir "$SKILL_DEST" || SKILL_DEST=""

# If neither path is writable, nothing to do.
if [[ -z "$EXT_DEST" && -z "$SKILL_DEST" ]]; then
  echo "[gemini] No writable skill/extension dir under ~/.gemini — skipping. Run 'gemini extensions install https://github.com/cskwork/multica-skill' instead." >&2
  exit 0
fi

if [[ -n "$SKILL_DEST" ]]; then
  for skill in multica multica-workflow multica-onboarding; do
    src="${REPO_ROOT}/skills/${skill}"
    if [[ ! -d "$src" ]]; then continue; fi
    rm -rf "${SKILL_DEST}/${skill}"
    ln -s "$src" "${SKILL_DEST}/${skill}"
    echo "[gemini] linked ${SKILL_DEST}/${skill}"
  done
fi

# If `gemini` CLI is present, also register as an extension pack
if [[ -n "$EXT_DEST" ]] && command -v gemini >/dev/null 2>&1; then
  if [[ ! -e "${EXT_DEST}/multica-skill" ]]; then
    ln -s "$REPO_ROOT" "${EXT_DEST}/multica-skill"
    echo "[gemini] linked ${EXT_DEST}/multica-skill → $REPO_ROOT"
  fi
fi

echo "[gemini] Done. Run 'gemini extensions list' to verify."
