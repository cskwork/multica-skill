#!/usr/bin/env bash
# Install Playwright (project-scoped) + the playwright-cli skill (user-scoped).
# Run from your project root.
set -euo pipefail

SKILL_REPO_RAW="https://raw.githubusercontent.com/barjakuzu/playwright-cli-skill/main/SKILL.md"
SKILL_REPO="https://github.com/barjakuzu/playwright-cli-skill"

log()  { printf "[playwright] %s\n" "$*" >&2; }
warn() { printf "[playwright] WARN: %s\n" "$*" >&2; }

PREREQ_ONLY=0
SKIP_PREREQ=0
for arg in "$@"; do
  case "$arg" in
    --prereq-only)         PREREQ_ONLY=1 ;;
    --skip-prereq-check)   SKIP_PREREQ=1 ;;
  esac
done

# --- 1. Project-scoped: @playwright/test --------------------------------------
if [[ "$SKIP_PREREQ" -eq 0 ]]; then
  if [[ ! -f "package.json" ]]; then
    warn "No package.json in current dir — Playwright is per-project."
    warn "cd into your project root and re-run, or initialize one: npm init -y"
  else
    if ! grep -q '@playwright/test' package.json 2>/dev/null; then
      log "Adding @playwright/test to devDependencies"
      npm install --save-dev @playwright/test
    else
      log "@playwright/test already in package.json"
    fi
    log "Installing browser binaries (npx playwright install --with-deps)"
    npx playwright install --with-deps || warn "browser install failed — re-run later"
  fi

  # --- e2e scaffold ----------------------------------------------------------
  if [[ -f "package.json" && ! -d "e2e" ]]; then
    log "Scaffolding e2e/"
    mkdir -p e2e/specs e2e/scripts e2e/artifacts
    cat > e2e/playwright.config.ts <<'EOF'
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './specs',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: 'list',
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
});
EOF
    cat > e2e/_env.example.sh <<'EOF'
# Copy to _env.sh (gitignored) and fill in.
export BASE_URL="http://localhost:3000"
export QA_TEST_USER_ID="qa@example.com"
export QA_TEST_USER_PASSWORD="change-me"
EOF
    cat > e2e/specs/smoke.spec.ts <<'EOF'
import { test, expect } from '@playwright/test';

test('homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/.+/);
});
EOF
    # gitignore artifacts and env
    if [[ -f ".gitignore" ]]; then
      grep -q "e2e/artifacts" .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

# multica-skill / playwright
e2e/artifacts/
e2e/_env.sh
storageState.json
test-results/
playwright-report/
EOF
    fi
    log "  e2e/ scaffolded: playwright.config.ts, specs/smoke.spec.ts, _env.example.sh"
  fi
fi

[[ "$PREREQ_ONLY" -eq 1 ]] && { log "Done (prereq-only)."; exit 0; }

# --- 2. User-scoped: the playwright-cli skill ---------------------------------
fetch_skill() {
  local dest="$1"
  mkdir -p "$dest"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$SKILL_REPO_RAW" -o "$dest/SKILL.md" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest/SKILL.md" "$SKILL_REPO_RAW" || return 1
  else
    local tmp; tmp="$(mktemp -d)"
    git clone --depth=1 "$SKILL_REPO" "$tmp" >/dev/null 2>&1 || return 1
    cp "$tmp/SKILL.md" "$dest/SKILL.md"
    rm -rf "$tmp"
  fi
  log "  installed: $dest/SKILL.md"
}

installed_any=0

if command -v multica >/dev/null 2>&1; then
  log "Multica → multica skill import"
  if multica skill list 2>/dev/null | grep -q "playwright"; then
    log "  already imported"
  else
    multica skill import "$SKILL_REPO" || warn "import failed"
  fi
  installed_any=1
fi

if command -v claude >/dev/null 2>&1; then
  log "Claude Code → ~/.claude/skills/playwright-cli/"
  fetch_skill "${HOME}/.claude/skills/playwright-cli" && installed_any=1
fi
if command -v codex >/dev/null 2>&1; then
  log "Codex → ~/.codex/skills/playwright-cli/"
  fetch_skill "${HOME}/.codex/skills/playwright-cli" && installed_any=1
fi
if command -v gemini >/dev/null 2>&1; then
  log "Gemini → ~/.gemini/skills/playwright-cli/"
  fetch_skill "${HOME}/.gemini/skills/playwright-cli" && installed_any=1
fi
if command -v opencode >/dev/null 2>&1; then
  log "OpenCode → ~/.config/opencode/skills/playwright-cli/"
  fetch_skill "${HOME}/.config/opencode/skills/playwright-cli" && installed_any=1
fi
if command -v pi >/dev/null 2>&1; then
  log "Pi → ~/.pi/skills/playwright-cli/"
  fetch_skill "${HOME}/.pi/skills/playwright-cli" && installed_any=1
fi

if [[ "$installed_any" -eq 0 ]]; then
  warn "No supported harness detected. The Playwright binary is installed in the project, but the skill SKILL.md was not copied anywhere."
fi

log "Done."
