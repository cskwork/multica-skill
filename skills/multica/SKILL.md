---
name: multica
description: Operate Multica boards, agent dispatch, runtime setup, and its explore/work/review/QA workflow. Use for Multica-specific tasks, not generic ticket or agent management.
---

# multica: CLI, onboarding, and workflow

`multica` is the local CLI for [Multica](https://multica.ai), the open-source managed-agents platform. It connects your machine to a Multica server, manages the board (workspaces, projects, issues, comments), wires AI coding tools as **agents**, and runs a **daemon** that picks up assigned work and dispatches it to those tools.

Treat assignment, agent mentions, daemon/autopilot start, and status changes that dispatch work as execution actions. Use the user-authorized project, issue, and runtime scope; inspection alone does not authorize dispatch or comments.

This single skill is the reference card. Deep detail lives in `references/`:

- **Read `references/cli-reference.md` before running a `multica` command whose flags you have not confirmed.** Every CLI command, by area, with exact flags.
- **Read `references/onboarding.md` before the first command on a machine with no `~/.multica/config.json`.** First-run setup: install → `setup` → verify runtime → create agent → first task.
- **Read `references/workflow.md` before moving an issue between phases.** The explore→work→review→qa→learn pipeline on Multica's fixed states, with rewind logic and copy-paste shell recipes.

## Mental model

```
Workspace ──┐
            └── Project ── Issue (MUL-123) ── Comment ── (sub-issues via --parent)
                            │
                            ├── status:   backlog | todo | in_progress | in_review | done | blocked | cancelled  (fixed)
                            ├── priority: urgent | high | medium | low | none
                            ├── metadata: key=value (pipeline_status, pr_url, ... — the CLI's first-class side channel)
                            └── assignee: a person OR an Agent (one AI coding tool + system instructions + skills)
```

Three rules that drive everything:

1. **Assignment IS dispatch.** Assigning an issue to an agent (or creating it with `--assignee` at a non-`backlog` status) makes the daemon claim it and run the tool automatically. `backlog` parks the assignee without firing.
2. **`@agent-name` in a comment** triggers a fresh run on that issue.
3. **States are fixed; `metadata` is the free channel.** There is no label-setting CLI command, so encode sub-phases and durable state with `multica issue metadata set`, query with `multica issue list --metadata key=value`.

## Quick start

```bash
multica setup          # configure + browser login (saves a PAT to ~/.multica/config.json) + start daemon
multica auth status    # confirm who you are and which workspace
multica issue list     # see the board (prints copy-paste keys like MUL-123)
```

New machine from scratch → follow **`references/onboarding.md`**.

## Command index

Run `multica <command> --help` for full flags. Exact forms are in `references/cli-reference.md`.

| Area | Commands |
|------|----------|
| Auth & setup | `login [--token mul_…]` · `auth status` · `auth logout` · `setup` (Cloud) · `setup self-host` |
| Daemon | `daemon start [--foreground]` · `stop` · `restart` · `status` · `logs` |
| Workspaces | `workspace list [--full-id] [--output json]` · `get` · `member list` · `switch <id\|slug>` · `update` |
| Issues | `issue list` (filters) · `get` · `create` · `update` · `assign --to\|--to-id\|--unassign` · `status <id> <state>` · `search` · `runs` · `rerun` · `run-messages` · `comment add\|list\|delete` · `subscriber` · `metadata set\|get\|list\|delete` · `pull-requests` |
| Projects | `project list\|get\|create\|update\|status\|delete` |
| Agents | `agent list\|get\|create\|update\|archive\|restore\|tasks\|skills\|env get` |
| Skills | `skill list\|get\|create\|update\|delete\|import\|files` |
| Squads | `squad list\|get\|create\|update\|delete\|member\|activity` |
| Autopilots | `autopilot list\|get\|create\|update\|delete\|runs\|trigger\|trigger-add\|trigger-update\|trigger-delete` |
| Runtimes | `runtime list\|usage\|activity\|update` |
| Misc | `repo checkout <url>` · `config show\|set` · `attachment download <id>` · `version` · `update` |

## The workhorse: issues

```bash
# List / filter (filters: --status --priority --assignee/--assignee-id --project --metadata --limit)
multica issue list --status in_progress --priority high
multica issue list --metadata pipeline_status=review
multica issue get MUL-142                 # accepts the short key or a full UUID

# Create (flags: --title (req) --description --status --priority --assignee/--assignee-id --parent --project --due-date)
multica issue create --title "Add CSV export to /reports" --priority high --assignee "Lambda"

# Dispatch / reassign an existing issue
multica issue assign MUL-142 --to "Lambda"        # or --to-id <uuid>, or --unassign
multica issue status MUL-142 in_progress          # status is a positional arg, any → any

# Comment (also a dispatch surface via @mention)
multica issue comment add MUL-142 --content "@reviewer please review the diff"
```

> **Assign only a workable agent.** `multica issue assign` should target an agent whose runtime is actually online and claiming work, or the server cancels the task after a short window. Pre-flight: `multica runtime list` (STATUS online) + `multica agent list`, and tail `multica daemon logs` if unsure. Resolve agent/runtime IDs at call time.

## Agents and skills

```bash
multica agent list                         # see slugs, providers, status
multica agent create                       # required: name + runtime (AI tool); rest optional — see --help
multica skill import --url https://github.com/cskwork/multica-skill   # import this bundle
multica agent skills <agent-slug>          # attach/detach a skill to an agent (nested)
```

Agent optional fields (all changeable later): system instructions, model, `custom_env`, `custom_args`, visibility (`private` default), `max_concurrent_tasks` (default 6). Details in `references/cli-reference.md`. Secrets in `custom_env` are stored plaintext server-side, so use limited-scope credentials.

## Workflow in one breath

Drive a ticket through phases with **`metadata` + status + reassignment**, fresh context each phase:

```
explore ─▶ work ─▶ review ─▶ qa ─▶ learn ─▶ done
   ▲                  │        │
   └──── rewind ──────┴────────┘   (review/qa finds an issue → back to work)
```

Encode the phase as `metadata pipeline_status=<phase>`, move `status` across the fixed states, and `assign` the next agent. Full state diagram, rewind rules (3 consecutive QA fails → `blocked` + ping a subscriber), and ready-to-run advance/rewind shell snippets are in **`references/workflow.md`**.

## Troubleshooting (quick)

| Symptom | Fix |
|---------|-----|
| `auth status` unauthenticated | `multica login` (browser) or `multica login --token mul_…` |
| Agent assigned, no run | `multica daemon status` → `multica daemon start`; confirm runtime online |
| Run stalls | `multica daemon logs`; check `max_concurrent_tasks` (agent) and daemon cap (default 20) |
| `skill import` fails | repo needs a discoverable `SKILL.md`; default `--on-conflict fail`, use `overwrite\|rename\|skip` |
| Slow network timeouts | `MULTICA_HTTP_TIMEOUT=60s multica …` (default 30s) |

## See also

- Multica docs: [cli](https://multica.ai/docs/cli) · [agents](https://multica.ai/docs/agents-create) · [skills](https://multica.ai/docs/skills) · [issues](https://multica.ai/docs/issues) · [daemon & runtimes](https://multica.ai/docs/daemon-runtimes) · [autopilots](https://multica.ai/docs/autopilots) · [squads](https://multica.ai/docs/squads)
