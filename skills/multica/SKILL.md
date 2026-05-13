---
name: multica
description: Use whenever the user mentions "multica", asks to create/move/comment a ticket, dispatches an AI coding tool to a board task, manages workspaces/projects/agents/skills/daemon/autopilot, or asks "how do I X with multica" — covers login, issues, agents, skills, daemon, autopilot, runtimes, and PAT setup.
---

# multica — CLI usage skill

`multica` is the local CLI for the [Multica](https://multica.ai) coordination platform. It manages workspaces, projects, issues, AI-coding agents, skills, and the local daemon that polls work and dispatches it to underlying coding tools (Claude Code, Codex, Cursor, Copilot, Gemini, Hermes, …).

This skill is the **reference card**. Other skills (`multica-workflow`, `multica-onboarding`) call into it.

## Mental model

```
Workspace ──┐
            └── Project ── Issue (MUL-123) ── Comment
                              │
                              ├── status: backlog | todo | in_progress | in_review | done | blocked | cancelled
                              ├── priority: urgent | high | medium | low | none
                              ├── labels: phase:explore, phase:work, phase:review, phase:qa, phase:learn, …
                              └── assignee: person OR Agent (an AI coding tool wired with system prompt + skills)
```

- **Issues are the unit of work.** Agents are wired to tools (`claude-code`, `codex`, `cursor`, `copilot`, `gemini`, `hermes`, …).
- **Assignment IS dispatch.** Assigning an issue to an agent makes the daemon pick it up and run the agent against it automatically.
- **`@agent-name` in a comment** also triggers a run on the existing issue.
- **States are fixed**, but **labels are free** — we use `phase:*` labels to encode sub-phases inside `in_progress` and `in_review`.

## Install + auth

```bash
# Install (desktop bundle ships the CLI + daemon)
open https://multica.ai/download
# or check if already installed
which multica && multica --version

# Login (browser flow, saves PAT to ~/.multica/config.json)
multica login

# Headless / CI
multica login --token mul_XXXXXXXX

# Verify
multica auth status
```

PATs are created in the web app at **Settings → Personal Access Tokens**.

## Start the daemon (required for agent dispatch)

```bash
multica daemon start           # background
multica daemon start --foreground   # for debugging
multica daemon status
multica daemon logs -f         # tail
multica daemon restart
multica daemon stop
```

Useful env vars:
- `MULTICA_SERVER_URL` — point CLI/daemon at self-hosted instance
- `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` — default 20
- `MULTICA_<PROVIDER>_PATH`, `MULTICA_<PROVIDER>_MODEL` — override per-tool binary/model (e.g. `MULTICA_CLAUDE_PATH=/usr/local/bin/claude`)

## Workspaces

```bash
multica workspace list
multica workspace get <slug>
multica workspace members
multica workspace update <id> --name "Eng" --issue-prefix "ENG"
```

## Projects

```bash
multica project list
multica project get <id>
multica project create --name "Reports v2" --description-stdin <<<"Q2 backlog"
multica project update <id> --name "Reports v2 (frozen)"
multica project status <id>     # progress summary
multica project delete <id>
```

## Issues — the workhorse

```bash
# List / filter
multica issue list
multica issue list --state todo --label phase:explore
multica issue search "csv export"
multica issue get MUL-142
multica issue get --full-id MUL-142     # canonical UUID

# Create
multica issue create \
  --title "Add CSV export to /reports" \
  --description-stdin <<'EOF'
Customers want to export the reports table as CSV.
Acceptance:
- button next to "Filter" in /reports
- streams response, no full buffer
- 100k rows < 5s
EOF

multica issue create \
  --title "..." \
  --label phase:explore \
  --priority high \
  --context-stdin < repo-context.md

# Dispatch — assigning IS starting
multica issue assign MUL-142 --agent claude-explorer
multica issue assign MUL-142 --agent codex-reviewer  # reassign mid-flight

# State transitions (any → any allowed)
multica issue status MUL-142 --set in_progress
multica issue status MUL-142 --set in_review
multica issue status MUL-142 --set done
multica issue status MUL-142 --set blocked

# Labels (used for sub-phases — see multica-workflow)
multica issue label MUL-142 --add phase:work --remove phase:explore

# Comments — also a dispatch surface
multica issue comment MUL-142 "@claude-reviewer review the latest diff"
```

> **JSON output:** Multica's CLI does **not** document a `--json` / `--output json` flag at the time of writing. For programmatic use, prefer the daemon's events stream or parse stable lines with `awk`/`grep`. The `multica-flow` companion CLI in this bundle works around this by reading `multica issue get` text output.

## Agents — wire one AI tool per role

```bash
multica agent list
multica agent create \
  --slug claude-explorer \
  --tool claude-code \
  --model opus \
  --system-instructions "You are the Explore-phase agent. Read the ticket, the repo, and the wiki. Produce a Domain Brief + 2-3 Plan Candidates. Do NOT write code." \
  --custom-args '["--max-turns","30"]' \
  --max-concurrent-tasks 3
multica agent update claude-explorer --visibility workspace
multica agent archive <slug>
multica agent restore <slug>
multica agent tasks       # what's currently running
```

> Agents are **per-role**, not per-ticket. Wire `<tool>-<phase>` agents once (`claude-explorer`, `codex-implementer`, `gemini-reviewer`, `claude-qa`, …) and reuse them across all tickets via `multica issue assign`.

### Assignment safety rule — only target a **workable** agent

`multica issue assign` MUST target an agent whose daemon is currently picking up tasks. An agent shown as `idle` in `multica agent list` is not necessarily reachable — the underlying runtime may be offline on the device that owns it, and the daemon will cancel the task after a short execution window (observed: `task cancelled by server, interrupting agent` after ~2 min when the agent's runtime is registered but not actually claiming work).

**Mandatory pre-flight before every assign:**

```bash
# 1. Confirm the runtime backing this agent is online on a reachable device
multica runtime list           # filter for STATUS=online and the right provider/device

# 2. Confirm the agent itself is workable
#    - STATUS = "working"  → demonstrably online, your task will queue
#    - STATUS = "idle"     → only safe if a recent task on this agent succeeded
multica agent list

# 3. If unsure, tail the daemon log for recent activity on the agent's tasks
multica daemon logs -f
```

**Default preference order** (claude first, codex as fallback):

1. The agent wired to the `claude-code` provider whose runtime is `online` on the current device — proven to claim tasks. Use this unless you have a specific reason otherwise.
2. The agent wired to the `codex` provider — fallback when claude is saturated, offline, or repeatedly cancels.

Skip any agent that you have just seen the server cancel without an obvious cause — re-check its runtime row in `multica runtime list` first. Resolve agent and runtime UUIDs at call time from `multica agent list` / `multica runtime list`; do not hard-code them, they are per-workspace and per-device.

## Skills — what this repo ships

```bash
multica skill list
multica skill get multica-workflow
multica skill import https://github.com/cskwork/multica-skill    # this repo
multica skill import ./local-skill-dir
multica skill import claw://<id>                                  # ClawHub
multica skill update multica-workflow --content-stdin < SKILL.md
multica skill delete some-old-skill
```

**MCP note:** Multica passes MCP config through to agents, but per [docs/skills](https://multica.ai/docs/skills) "MCP support is only truly consumed by Claude Code today; other tools receive the MCP config but don't actively use it." Plan accordingly when designing skills that depend on MCP servers.

## Autopilot — scheduled / event-triggered runs

```bash
multica autopilot list
multica autopilot trigger <autopilot-id>
multica autopilot runs <autopilot-id>
```

Useful for nightly QA sweeps, dependency upgrades, or weekly wiki updates.

## Runtimes — what the daemon can drive

```bash
multica runtime list      # claude-code, codex, cursor, copilot, gemini, hermes, …
multica runtime usage     # token/$ accounting per runtime
```

## Common recipes

**Create + dispatch in one command:**
```bash
ID=$(multica issue create --title "$TITLE" --label phase:explore | grep -oE 'MUL-[0-9]+')
multica issue assign "$ID" --agent claude-explorer
echo "Dispatched $ID"
```

**Reassign on phase transition (the core of `multica-workflow`):**
```bash
multica issue label MUL-142 --remove phase:explore --add phase:work
multica issue status MUL-142 --set in_progress
multica issue assign MUL-142 --agent codex-implementer
```

**Drain a phase manually if the daemon is offline:**
```bash
for id in $(multica issue list --state todo --label phase:explore | awk '{print $1}'); do
  multica issue assign "$id" --agent claude-explorer
done
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `multica auth status` says unauthenticated | `multica login` (browser) or `multica login --token mul_…` |
| Agent assigned but no run starts | `multica daemon status` — daemon may be stopped. `multica daemon start`. |
| Agent runs but stalls | `multica daemon logs -f`. Check `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` and the agent's own `max_concurrent_tasks`. |
| `multica skill import <github-url>` fails | The repo must contain a discoverable `SKILL.md` (top-level or under `skills/<name>/`). Try `multica skill import ./cloned-dir` first to confirm structure. |
| CI run can't auth | `multica login --token "$MULTICA_PAT"` — do NOT bake the token into the image. |

## See also

- [`multica-workflow`](../multica-workflow/SKILL.md) — full coding pipeline using this CLI
- [`multica-onboarding`](../multica-onboarding/SKILL.md) — first-run setup
- Multica docs: [cli](https://multica.ai/docs/cli), [agents](https://multica.ai/docs/agents), [skills](https://multica.ai/docs/skills), [issues](https://multica.ai/docs/issues), [daemon](https://multica.ai/docs/daemon-runtimes), [auth-tokens](https://multica.ai/docs/auth-tokens), [env vars](https://multica.ai/docs/environment-variables)
