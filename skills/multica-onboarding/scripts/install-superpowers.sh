#!/usr/bin/env bash
# Install obra/superpowers across whichever harness(es) are present.
# Idempotent — safe to re-run.
set -euo pipefail

REPO="https://github.com/obra/superpowers"
MARKETPLACE="obra/superpowers-marketplace"

log()  { printf "[superpowers] %s\n" "$*" >&2; }
warn() { printf "[superpowers] WARN: %s\n" "$*" >&2; }

installed_any=0

# --- Multica (treat as first-class) -----------------------------------------
if command -v multica >/dev/null 2>&1; then
  log "Multica detected → multica skill import"
  if multica skill list 2>/dev/null | grep -q "superpowers"; then
    log "  already imported"
  else
    multica skill import "$REPO" || warn "import failed (continuing)"
  fi
  installed_any=1
fi

# --- Claude Code ------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  log "Claude Code detected → /plugin install"
  # The plugin command is interactive; we wire it via a one-shot file.
  CC_DIR="${HOME}/.claude"
  mkdir -p "$CC_DIR/plugins"
  if [[ ! -d "$CC_DIR/plugins/superpowers" ]]; then
    git clone --depth=1 "$REPO" "$CC_DIR/plugins/superpowers" 2>/dev/null || \
      warn "git clone failed — try '/plugin marketplace add $MARKETPLACE' inside Claude Code instead"
  else
    (cd "$CC_DIR/plugins/superpowers" && git pull --ff-only) || warn "git pull failed"
  fi
  # Also drop into ~/.claude/skills/ for harness-direct discovery
  mkdir -p "$CC_DIR/skills"
  ln -sfn "$CC_DIR/plugins/superpowers/skills" "$CC_DIR/skills/_superpowers" 2>/dev/null || true
  installed_any=1
fi

# --- Codex ------------------------------------------------------------------
if command -v codex >/dev/null 2>&1; then
  log "Codex detected → ~/.codex/plugins/superpowers/"
  mkdir -p "${HOME}/.codex/plugins"
  if [[ ! -d "${HOME}/.codex/plugins/superpowers" ]]; then
    git clone --depth=1 "$REPO" "${HOME}/.codex/plugins/superpowers" || warn "clone failed"
  else
    (cd "${HOME}/.codex/plugins/superpowers" && git pull --ff-only) || warn "pull failed"
  fi
  installed_any=1
fi

# --- Gemini -----------------------------------------------------------------
if command -v gemini >/dev/null 2>&1; then
  log "Gemini detected → extensions install"
  gemini extensions install "$REPO" 2>/dev/null || {
    warn "extensions install failed → fallback clone to ~/.gemini/extensions/"
    mkdir -p "${HOME}/.gemini/extensions"
    [[ -d "${HOME}/.gemini/extensions/superpowers" ]] || \
      git clone --depth=1 "$REPO" "${HOME}/.gemini/extensions/superpowers" || true
  }
  installed_any=1
fi

# --- OpenCode ---------------------------------------------------------------
if command -v opencode >/dev/null 2>&1; then
  log "OpenCode detected → ~/.config/opencode/skills/superpowers/"
  mkdir -p "${HOME}/.config/opencode/skills"
  if [[ ! -d "${HOME}/.config/opencode/skills/superpowers" ]]; then
    git clone --depth=1 "$REPO" "${HOME}/.config/opencode/skills/superpowers" || warn "clone failed"
  fi
  installed_any=1
fi

# --- Pi ---------------------------------------------------------------------
if command -v pi >/dev/null 2>&1; then
  log "Pi detected → ~/.pi/skills/superpowers/"
  mkdir -p "${HOME}/.pi/skills"
  if [[ ! -d "${HOME}/.pi/skills/superpowers" ]]; then
    git clone --depth=1 "$REPO" "${HOME}/.pi/skills/superpowers" || warn "clone failed"
  fi
  installed_any=1
fi

# --- Droid (factory.ai) -----------------------------------------------------
if command -v droid >/dev/null 2>&1; then
  log "Droid detected → droid plugin install"
  droid plugin install "superpowers@superpowers" 2>/dev/null || warn "plugin install failed"
  installed_any=1
fi

if [[ "$installed_any" -eq 0 ]]; then
  warn "No supported harness detected (multica / claude / codex / gemini / opencode / pi / droid)."
  warn "Manually: git clone $REPO into your harness's skills directory."
  exit 1
fi

log "Done."
