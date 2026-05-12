---
name: multica-onboarding
description: Use on first run of multica-skill, when the user says "set up multica skills", "bootstrap multica", "register default skills", "install superpowers/playwright/atlassian-cli", or "onboard a new project with multica". Verifies multica CLI auth and installs the three default skill packs that the workflow expects to be available.
---

# multica-onboarding — register the defaults

This skill is run **once per machine** (or once per project, depending on which scope the user chooses). It establishes a known-good baseline before any tickets enter the pipeline.

## What it installs

1. **[obra/superpowers](https://github.com/obra/superpowers)** — the spine. 14 skills covering brainstorming, planning, TDD, debugging, subagent dispatch, code review (both giving and receiving), worktrees, branch finalization. Every other skill in this bundle plugs into one of these phases.
2. **[leweii/atlassian-cli](https://github.com/leweii/atlassian-cli)** — the Jira/Confluence bridge skill (wraps Atlassian's official `acli` binary). Lets agents read tickets, transition issues, and post comments from inside their session.
3. **Playwright** (`@playwright/test` + browsers) plus the `playwright-cli-skill` — the QA gate. Used by the QA phase to produce real browser evidence (trace.zip + video.webm + screenshots) for any web-touching ticket.

## Run order (each step depends on the previous)

```bash
# 1. Preflight — make sure multica itself is healthy
multica auth status
multica daemon status   # if not running: multica daemon start

# 2. superpowers — sets the workflow vocabulary
bash scripts/install-superpowers.sh

# 3. playwright — project-scoped, brings QA evidence pipeline online
bash scripts/install-playwright.sh        # run from your project root

# 4. atlassian-cli — last, because it depends on an external binary + login
bash scripts/install-atlassian-cli.sh
```

After these run successfully, the workflow agents have everything they need.

## Verification

```bash
# superpowers
case "$HARNESS" in
  claude)   claude --version && /plugin list | grep superpowers ;;
  gemini)   gemini extensions list | grep superpowers ;;
  codex)    ls ~/.codex/plugins/ | grep superpowers ;;
esac

# playwright
npx playwright --version
ls e2e/ 2>/dev/null && echo "e2e scaffold present"

# atlassian-cli
acli --version 2>/dev/null && acli auth status
ls ~/.claude/skills/atlassian-cli/SKILL.md  # or wherever your harness reads skills from
```

## Adapter-aware

The install scripts detect which harness is present and route accordingly:

| Harness | superpowers | atlassian-cli | playwright |
|---------|-------------|---------------|------------|
| Claude Code | `/plugin install superpowers@superpowers-marketplace` | `cp SKILL.md → ~/.claude/skills/atlassian-cli/` | `npm i -D @playwright/test && cp SKILL.md → ~/.claude/skills/playwright-cli/` |
| Codex | clone to `~/.codex/plugins/superpowers/` | clone to `~/.codex/skills/atlassian-cli/` | clone to `~/.codex/skills/playwright-cli/` |
| Gemini | `gemini extensions install https://github.com/obra/superpowers` | extension or `~/.gemini/skills/` | extension or `~/.gemini/skills/` |
| OpenCode | clone to `~/.config/opencode/skills/superpowers/` | clone to `~/.config/opencode/skills/atlassian-cli/` | clone to `~/.config/opencode/skills/playwright-cli/` |
| Pi | clone to `~/.pi/skills/superpowers/` | clone to `~/.pi/skills/atlassian-cli/` | clone to `~/.pi/skills/playwright-cli/` |
| Multica (native) | `multica skill import https://github.com/obra/superpowers` | `multica skill import https://github.com/leweii/atlassian-cli` | `multica skill import https://github.com/barjakuzu/playwright-cli-skill` |

The install scripts in [`scripts/`](scripts/) handle this branching automatically — you do not need to memorize the table.

## When to re-run

- **You added a new harness** to your toolkit (e.g. installed Codex after using only Claude Code).
- **You moved to a new machine.**
- **You spun up a new project** where Playwright isn't installed yet — re-run just `install-playwright.sh` inside the project root.
- **Atlassian's `acli` reauth expired** — re-run `install-atlassian-cli.sh` (it will detect and prompt for `acli auth login`).

## Skipping a default

Each script accepts `--skip-prereq-check` if you want to install the SKILL.md only without the underlying binary. Reverse: each script accepts `--prereq-only` if you have the SKILL.md elsewhere and just need the dependency.

## See also

- [`multica`](../multica/SKILL.md) — CLI used throughout
- [`multica-workflow`](../multica-workflow/SKILL.md) — what consumes these defaults
- [`docs/HARNESSES.md`](../../docs/HARNESSES.md) — full adapter matrix
