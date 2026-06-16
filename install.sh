#!/usr/bin/env bash
# install.sh — install the single `multica` skill into whatever harness is present.
#
# Usage:
#   ./install.sh              # auto-detect and install for every harness present
#   ./install.sh claude-code  # a specific harness
#   ./install.sh multica      # import into Multica via `multica skill import`
#   ./install.sh --all        # run every adapter regardless of detection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ADAPTERS_DIR="${REPO_ROOT}/adapters"

ALL_HARNESSES=(multica claude-code codex gemini opencode pi)

detected() {
  local h="$1"
  case "$h" in
    multica)     command -v multica  >/dev/null 2>&1 ;;
    claude-code) command -v claude   >/dev/null 2>&1 ;;
    codex)       command -v codex    >/dev/null 2>&1 ;;
    gemini)      command -v gemini   >/dev/null 2>&1 ;;
    opencode)    command -v opencode >/dev/null 2>&1 ;;
    pi)          command -v pi       >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

run_adapter() {
  local h="$1"
  case "$h" in
    multica)
      if command -v multica >/dev/null 2>&1; then
        echo "[install] Multica detected → multica skill import $REPO_ROOT"
        multica skill import "$REPO_ROOT" 2>/dev/null || {
          echo "[install]   local import failed; try: multica skill import --url https://github.com/cskwork/multica-skill"
        }
      else
        echo "[install] multica CLI not found — skip"
      fi
      ;;
    *)
      local script="${ADAPTERS_DIR}/${h}.sh"
      if [[ -x "$script" ]]; then
        bash "$script"
      else
        echo "[install] No adapter for '$h' at $script" >&2
        return 1
      fi
      ;;
  esac
}

TARGETS=()

if [[ $# -eq 0 ]]; then
  for h in "${ALL_HARNESSES[@]}"; do
    if detected "$h"; then TARGETS+=("$h"); fi
  done
elif [[ "${1:-}" == "--all" ]]; then
  TARGETS=("${ALL_HARNESSES[@]}")
else
  TARGETS=("$@")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "[install] No supported harness detected on this machine."
  echo "[install] Supported: ${ALL_HARNESSES[*]}"
  echo "[install] Pass one explicitly or run: ./install.sh --all"
  exit 1
fi

echo "[install] Targets: ${TARGETS[*]}"
echo

for h in "${TARGETS[@]}"; do
  run_adapter "$h" || echo "[install] $h adapter exited non-zero (continuing)"
  echo
done

chmod +x "${ADAPTERS_DIR}"/*.sh 2>/dev/null || true

cat <<EOF
[install] Done. The 'multica' skill is installed.

Next:
  - Inside your harness, invoke /multica (or just mention "multica") to load the skill.
  - First time on this machine? Follow skills/multica/references/onboarding.md.
  - Run a pipeline? See skills/multica/references/workflow.md.
EOF
