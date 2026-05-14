# multica-skill

Harness-agnostic skill bundle that turns any [Multica](https://multica.ai) board into a **full coding pipeline** — `todo → explore → work → review → qa → done` — drivable from Claude Code, Codex, Gemini, OpenCode, Pi, Cursor, Copilot, or Hermes.

> One ticket. Many agents. Each phase a fresh context. Failures rewind to `work`, not into the void.

---

## What's inside

| Skill | Purpose |
|-------|---------|
| **`multica`** | Day-to-day Multica CLI guide — login, issues, agents, daemon, autopilot. |
| **`multica-workflow`** | Symphony-style 5-lane pipeline mapped onto Multica's fixed 7 states via `phase:*` labels. Per-lane prompt templates + a small `multica-flow` CLI to advance/rewind tickets. |
| **`multica-onboarding`** | First-run bootstrap that registers three battle-tested default skills: **obra/superpowers**, **leweii/atlassian-cli**, and **Playwright**. |

### Operations docs (under `docs/`)

| Page | What it covers |
|------|----------------|
| [`HARNESSES.md`](docs/HARNESSES.md) | Tool-by-tool integration notes |
| [`WORKFLOW.md`](docs/WORKFLOW.md) | Phase semantics + transition matrix |
| [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Why the bundle is shaped this way |
| [`SEQUENTIAL_DISPATCH.md`](docs/SEQUENTIAL_DISPATCH.md) | Running 80+ issues in strict order, draining a zombie queue, working around `priority DESC` claim order |

### Battle-tested scripts (under `examples/`)

| Script | Purpose |
|--------|---------|
| `import-tasks-from-md.py` | Bulk-create Multica issues from a `tasks.md` checklist (with phase / difficulty labels, parent epic, auto-assign) |
| `rebalance-by-phase.py` | Reassign issues to the right agent based on `phase:*` label without changing status |
| `holdback-wave.py` | Reset stuck issues + flatten priorities + hold future waves in `backlog` |
| `wave-promoter.py` | Promote `phase:foundation` once all `phase:setup` are done, etc. |
| `strict-sequential.py` | Single-flight watcher — one issue at a time, in task-ID order |

The whole bundle is plain `SKILL.md` + bash, so every harness that reads markdown can consume it.

---

## Install

### Option 1 — Via Multica (recommended)

Multica has native skill import from GitHub:

```bash
multica skill import https://github.com/cskwork/multica-skill
multica skill list | grep multica
```

Then enable the bundle in any agent:

```bash
multica agent update <agent-slug> --skill multica --skill multica-workflow --skill multica-onboarding
```

### Option 2 — Any other harness

```bash
git clone https://github.com/cskwork/multica-skill ~/.multica-skill
cd ~/.multica-skill
./install.sh
```

`install.sh` detects what's installed (`claude`, `codex`, `gemini`, `opencode`, `pi`, `cursor`, `droid`) and runs the matching adapter. You can also target one explicitly:

```bash
./install.sh claude-code    # ~/.claude/skills/
./install.sh codex          # ~/.codex/commands/
./install.sh gemini         # gemini extensions install
./install.sh opencode       # ~/.config/opencode/commands/
./install.sh pi             # ~/.pi/skills/
```

After install, run the onboarding skill from inside your harness:

```
/multica-onboarding
```

It will:
1. Verify `multica` CLI is installed and authenticated.
2. Register `obra/superpowers` (via your harness's plugin/extension system).
3. Drop `leweii/atlassian-cli`'s `SKILL.md` into your skills dir (no-op if `acli` itself isn't installed).
4. Install `@playwright/test` + browsers into the current project, plus the `playwright-cli-skill`.

---

## The pipeline

Multica's states are fixed: `backlog | todo | in_progress | in_review | done | blocked | cancelled`. multica-workflow layers Symphony's richer lane semantics on top using **labels**:

```
backlog ─▶ todo ─▶ in_progress ─▶ in_progress ─▶ in_review ─▶ in_review ─▶ done
          phase:    phase:         phase:         phase:        phase:
          explore   work           review         qa            learn
```

Severity-based rewinds:

- **Review** finds CRITICAL / HIGH / MEDIUM → ticket bounces back to `in_progress / phase:work` with a fresh context. The agent reads `## Review Findings` (written into the ticket comments) and fixes only those.
- **QA** fails → same rewind, agent reads `## QA Failure`.
- Three consecutive QA failures on the same ticket → `blocked` + human ping.

See [`docs/WORKFLOW.md`](docs/WORKFLOW.md) for the full state diagram and [`skills/multica-workflow/lanes/`](skills/multica-workflow/lanes/) for the per-lane prompts.

---

## Quick taste

```bash
# Create a ticket and start the pipeline
multica issue create --title "Add CSV export to /reports" --label "phase:explore"
# → returns MUL-142

# Assign the explorer agent — Multica auto-starts it
multica issue assign MUL-142 --agent claude-explorer

# That's it. The agent writes ## Domain Brief into the ticket, swaps the label to
# phase:work, sets state=in_progress, and Multica's daemon picks the next phase.
# Watch progress:
multica issue get MUL-142
multica daemon logs -f
```

For an end-to-end walkthrough, see [`examples/csv-export-walkthrough.md`](examples/csv-export-walkthrough.md).

---

## Harness compatibility matrix

| Harness | Skill path | Adapter | Status |
|---------|-----------|---------|--------|
| Multica (native) | `multica skill import` | n/a | ✅ first-class |
| Claude Code | `~/.claude/skills/<name>/SKILL.md` | `adapters/claude-code.sh` | ✅ |
| Codex CLI | `~/.codex/commands/<name>.md` | `adapters/codex.sh` | ✅ |
| Gemini CLI | `gemini extensions install` | `adapters/gemini.sh` | ✅ |
| OpenCode | `~/.config/opencode/commands/<name>.md` | `adapters/opencode.sh` | ✅ |
| Pi | `~/.pi/skills/<name>/SKILL.md` | `adapters/pi.sh` | ✅ |
| Cursor | `.cursor/rules/<name>.mdc` | (via Multica or manual) | ⚠️ partial |
| Copilot | `.github/copilot-instructions.md` | (via Multica) | ⚠️ partial |

Multica's own agent system (Claude Code, Codex, Cursor, Copilot, Gemini, Hermes — 11 total) receives the skill through `multica skill import` regardless of which adapter you pick locally.

---

## Repo layout

```
multica-skill/
├── skills/
│   ├── multica/              # CLI usage guide
│   ├── multica-workflow/     # pipeline orchestration
│   │   ├── lanes/            # per-phase prompt templates
│   │   └── scripts/          # flow-next.sh, flow-rewind.sh
│   └── multica-onboarding/   # default-skill bootstrap
│       └── scripts/          # install-{superpowers,atlassian,playwright}.sh
├── adapters/                 # per-harness install scripts
├── bin/                      # multica-flow, multica-skill entrypoints
├── templates/                # workflow.yaml, ticket.md
├── docs/                     # WORKFLOW.md, HARNESSES.md, ARCHITECTURE.md
└── examples/                 # end-to-end walkthroughs
```

---

## License

MIT. See [LICENSE](LICENSE).

## Credits

- Pipeline shape ported from [cskwork/symphony-multi-agent](https://github.com/cskwork/symphony-multi-agent).
- Default skill picks: [obra/superpowers](https://github.com/obra/superpowers), [leweii/atlassian-cli](https://github.com/leweii/atlassian-cli), [Microsoft Playwright](https://playwright.dev).
- Built for [Multica](https://multica.ai)'s board + agent platform.
