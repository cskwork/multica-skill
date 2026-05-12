#!/usr/bin/env bash
# Install leweii/atlassian-cli skill across whichever harness(es) are present,
# and verify acli itself is installed + authenticated.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/leweii/atlassian-cli/main/SKILL.md"
REPO="https://github.com/leweii/atlassian-cli"

log()  { printf "[atlassian-cli] %s\n" "$*" >&2; }
warn() { printf "[atlassian-cli] WARN: %s\n" "$*" >&2; }

PREREQ_ONLY=0
SKIP_PREREQ=0
for arg in "$@"; do
  case "$arg" in
    --prereq-only)         PREREQ_ONLY=1 ;;
    --skip-prereq-check)   SKIP_PREREQ=1 ;;
  esac
done

# --- acli prerequisite ------------------------------------------------------
if [[ "$SKIP_PREREQ" -eq 0 ]]; then
  if ! command -v acli >/dev/null 2>&1; then
    log "acli not found. Install per https://developer.atlassian.com/cloud/cli/"
    if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
      log "On macOS — trying: brew install --cask atlassian-acli"
      brew install --cask atlassian-acli 2>/dev/null || warn "brew install failed; install manually"
    else
      warn "Install acli manually, then re-run this script."
      [[ "$PREREQ_ONLY" -eq 1 ]] && exit 1
    fi
  else
    log "acli present: $(acli --version 2>&1 | head -1)"
  fi

  if command -v acli >/dev/null 2>&1; then
    if ! acli auth status >/dev/null 2>&1; then
      log "acli not authenticated. Run: acli auth login"
    else
      log "acli authenticated."
    fi
  fi
fi

[[ "$PREREQ_ONLY" -eq 1 ]] && exit 0

# --- Skill installation across harnesses -----------------------------------
fetch_skill() {
  local dest="$1"
  mkdir -p "$dest"
  if [[ -f "$dest/SKILL.md" ]]; then
    log "  exists: $dest/SKILL.md (overwriting with latest)"
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW" -o "$dest/SKILL.md" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest/SKILL.md" "$REPO_RAW" || return 1
  else
    warn "Neither curl nor wget — falling back to git clone"
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth=1 "$REPO" "$tmp" >/dev/null 2>&1 || return 1
    cp "$tmp/SKILL.md" "$dest/SKILL.md"
    rm -rf "$tmp"
  fi
  log "  installed: $dest/SKILL.md"
}

installed_any=0

if command -v multica >/dev/null 2>&1; then
  log "Multica detected → multica skill import"
  if multica skill list 2>/dev/null | grep -q "atlassian-cli"; then
    log "  already imported"
  else
    multica skill import "$REPO" || warn "import failed"
  fi
  installed_any=1
fi

if command -v claude >/dev/null 2>&1; then
  log "Claude Code → ~/.claude/skills/atlassian-cli/"
  fetch_skill "${HOME}/.claude/skills/atlassian-cli" && installed_any=1
fi

if command -v codex >/dev/null 2>&1; then
  log "Codex → ~/.codex/skills/atlassian-cli/"
  fetch_skill "${HOME}/.codex/skills/atlassian-cli" && installed_any=1
fi

if command -v gemini >/dev/null 2>&1; then
  log "Gemini → ~/.gemini/skills/atlassian-cli/"
  fetch_skill "${HOME}/.gemini/skills/atlassian-cli" && installed_any=1
fi

if command -v opencode >/dev/null 2>&1; then
  log "OpenCode → ~/.config/opencode/skills/atlassian-cli/"
  fetch_skill "${HOME}/.config/opencode/skills/atlassian-cli" && installed_any=1
fi

if command -v pi >/dev/null 2>&1; then
  log "Pi → ~/.pi/skills/atlassian-cli/"
  fetch_skill "${HOME}/.pi/skills/atlassian-cli" && installed_any=1
fi

if [[ "$installed_any" -eq 0 ]]; then
  warn "No supported harness detected. Install acli, then manually copy SKILL.md to your harness's skills dir."
  exit 1
fi

log "Done."
