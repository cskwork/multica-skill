# multica-skill

A single, harness-agnostic [Agent Skill](https://agentskills.io) for the
[Multica](https://multica.ai) managed-agents platform. It teaches any coding
agent the **full `multica` CLI**, how to **onboard a machine**, and how to run a
**multi-phase coding pipeline** (explore → work → review → qa → learn) on a
Multica board.

> One skill. The whole CLI. Onboarding and workflow, mapped to the official docs.

📄 **Landing page:** [cskwork.github.io/multica-skill](https://cskwork.github.io/multica-skill/)

---

## What's inside

One skill, with heavy detail split into references (progressive disclosure — the
agent loads only what it needs):

| File | Purpose |
|------|---------|
| `skills/multica/SKILL.md` | The reference card: mental model, command index, the three rules that drive Multica. |
| `skills/multica/references/cli-reference.md` | Every CLI command by area, with exact flags. |
| `skills/multica/references/onboarding.md` | First run: install → `setup` → verify runtime → create agent → first task. |
| `skills/multica/references/workflow.md` | The explore→work→review→qa→learn pipeline, rewind logic, copy-paste shell recipes. |

Every command is checked against Multica's official `CLI_AND_DAEMON.md` and
`docs/cli` — no guessed flags.

---

## Install

### Option 1 — Via Multica (recommended)

```bash
multica skill import --url https://github.com/cskwork/multica-skill
multica skill list | grep multica
multica agent skills <agent-slug>      # attach it to an agent (nested command — see --help)
```

### Option 2 — Any other harness

```bash
git clone https://github.com/cskwork/multica-skill ~/.multica-skill
cd ~/.multica-skill
./install.sh                 # auto-detects claude / codex / gemini / opencode / pi
# or target one explicitly:
./install.sh claude-code     # → ~/.claude/skills/multica/
```

Then invoke `/multica` (or just mention "multica") inside your harness.

---

## The pipeline

Multica's states are fixed (`backlog | todo | in_progress | in_review | done |
blocked | cancelled`) and there is no label-setting CLI command, so the workflow
encodes each phase in **issue metadata** (`pipeline_status`) and moves status +
reassigns as it advances:

```
explore ─▶ work ─▶ review ─▶ qa ─▶ learn ─▶ done
   ▲                  │        │
   └──── rewind ◀──────┴────────┘     review or qa finds a problem → back to work
```

Each phase runs a fresh-context agent; review/qa failures rewind to `work` rather
than corrupting one long session. Three consecutive QA failures → `blocked` +
ping a human subscriber. Full state diagram and ready-to-run `advance.sh` /
`rewind.sh` snippets live in
[`skills/multica/references/workflow.md`](skills/multica/references/workflow.md).

---

## Quick taste

```bash
# Create a ticket, start exploring, and let the daemon dispatch the agent
ID=$(multica issue create --title "Add CSV export to /reports" --priority high \
       | grep -oE 'MUL-[0-9]+' | head -1)
multica issue metadata set "$ID" --key pipeline_status --value explore
multica issue assign "$ID" --to claude-explorer

# Watch it run
multica issue get "$ID"
multica daemon logs
```

---

## Harness compatibility

| Harness | Skill path | Adapter |
|---------|-----------|---------|
| Multica (native) | `multica skill import` | n/a — first-class |
| Claude Code | `~/.claude/skills/multica/` | `adapters/claude-code.sh` |
| Codex CLI | `~/.codex/skills/` + `~/.codex/commands/multica.md` | `adapters/codex.sh` |
| Gemini CLI | gemini extension | `adapters/gemini.sh` |
| OpenCode | `~/.config/opencode/skills/multica/` | `adapters/opencode.sh` |
| Pi | `~/.pi/skills/multica/` | `adapters/pi.sh` |

---

## Repo layout

```
multica-skill/
├── skills/multica/
│   ├── SKILL.md
│   └── references/
│       ├── cli-reference.md
│       ├── onboarding.md
│       └── workflow.md
├── adapters/              # per-harness install scripts (single skill)
├── docs/index.html        # GitHub Pages landing
├── install.sh
└── LICENSE
```

### Publishing the landing page

The landing page is a single self-contained file at `docs/index.html`. To serve
it: **Settings → Pages → Build from a branch → `main` / `/docs`**. It then lives
at `https://<owner>.github.io/multica-skill/`.

---

## License

MIT. See [LICENSE](LICENSE).

## Credits

- Pipeline shape ported from [cskwork/symphony-multi-agent](https://github.com/cskwork/symphony-multi-agent).
- Built for [Multica](https://multica.ai) — the open-source managed-agents platform.
