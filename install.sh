#!/usr/bin/env bash
# install.sh — detect installed harnesses and run their adapters.
#
# Usage:
#   ./install.sh              # auto-detect and install for every harness present
#   ./install.sh claude-code  # specific harness
#   ./install.sh multica      # also import into Multica via `multica skill import`
#   ./install.sh --all        # run every adapter regardless of detection
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ADAPTERS_DIR="${REPO_ROOT}/adapters"

# also wire up bin/ on PATH suggestion
BIN_DIR="${REPO_ROOT}/bin"

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
          echo "[install]   local import failed; try: multica skill import https://github.com/cskwork/multica-skill"
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
  # auto-detect
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
  echo "[install] Pass one explicitly or install --all."
  exit 1
fi

echo "[install] Targets: ${TARGETS[*]}"
echo

for h in "${TARGETS[@]}"; do
  run_adapter "$h" || echo "[install] $h adapter exited non-zero (continuing)"
  echo
done

# Make bin/ executable suggestion
chmod +x "${BIN_DIR}"/* 2>/dev/null || true
chmod +x "${ADAPTERS_DIR}"/*.sh 2>/dev/null || true
chmod +x "${REPO_ROOT}/skills/multica-onboarding/scripts/"*.sh 2>/dev/null || true

cat <<EOF
[install] Done.

Next steps:
  1. Add the CLI helpers to your PATH:
       export PATH="${BIN_DIR}:\$PATH"
  2. Inside any installed harness, invoke:
       /multica-onboarding
     to register obra/superpowers, leweii/atlassian-cli, and Playwright.
  3. Read docs/WORKFLOW.md and skills/multica-workflow/SKILL.md to wire phase agents.
EOF
