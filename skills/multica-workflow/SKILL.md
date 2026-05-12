---
name: multica-workflow
description: Use when running a full coding-task pipeline on a Multica board. Drives any ticket through explore → work → review → qa → learn → done with per-phase prompts, severity-based rewinds, and automatic agent dispatch. Activate whenever the user says "run this through multica", "set up the multica pipeline", "advance MUL-X to the next phase", "register a multica workflow ticket", or mentions phases like "phase:explore / phase:work / phase:review / phase:qa".
---

# multica-workflow — the coding pipeline

This skill ports the [Symphony multi-agent](https://github.com/cskwork/symphony-multi-agent) workflow onto Multica's board. Every ticket walks the same five phases. Each phase is a **fresh agent context** — the only contract between phases is what the previous agent wrote into the ticket.

```
            ┌─────────────────────── rewind on CRITICAL/HIGH/MEDIUM ───────────────┐
            │                                                                     │
            │              ┌─── rewind on QA failure ───┐                          │
            ▼              │                            │                          │
backlog ─▶ todo ─▶ in_progress ─▶ in_progress ─▶ in_review ─▶ in_review ─▶ done
          phase:    phase:         phase:         phase:        phase:
          explore   work           review         qa            learn
            │                                                                     │
            └──────────── 3× consecutive QA fail ─▶ blocked ──────────────────────┘
```

## Phase responsibilities

| Phase | State + label | Reads | Writes | Exit condition |
|-------|---------------|-------|--------|----------------|
| **Explore** | `todo` + `phase:explore` | Ticket, repo, wiki, prior tickets | `## Domain Brief`, `## Plan Candidates`, `## Recommendation` | Sets `phase:work`, `state:in_progress`, reassigns to implementer |
| **Work** | `in_progress` + `phase:work` | Ticket through `## Recommendation` | `## Implementation` with diff + test commands | Sets `phase:review`, `state:in_review`, reassigns to reviewer |
| **Review** | `in_review` + `phase:review` | Diff, ticket, repo style | `## Review Findings` graded CRITICAL/HIGH/MEDIUM/LOW | If any C/H/M → rewind to `phase:work`; else `phase:qa` |
| **QA** | `in_review` + `phase:qa` | Reviewed code | `## QA Evidence` with actual command output | If any fail → rewind to `phase:work`; else `phase:learn` |
| **Learn** | `in_review` + `phase:learn` | Whole ticket | `## Learnings`, optional `## Wiki Updates` | Sets `state:done`. Removes phase label. |

The agent **writes the next state itself** — the orchestrator (Multica's daemon) only reads tickets and dispatches. This is the same design principle as Symphony's tracker.

## How to use this skill

Three entry points:

### 1. Bootstrap once per workspace

```bash
multica-flow bootstrap
```

This creates the role agents you'll dispatch into (`<tool>-explorer`, `<tool>-implementer`, `<tool>-reviewer`, `<tool>-qa`, `<tool>-learner`) for your chosen tool. Configurable in `~/.multica-skill/workflow.yaml`. See [`templates/workflow.yaml`](../../templates/workflow.yaml).

### 2. Create a new ticket and start the pipeline

```bash
multica-flow new "Add CSV export to /reports"
# → MUL-142 created with phase:explore, assigned to claude-explorer
```

Or directly:
```bash
multica issue create --title "..." --label phase:explore
multica issue assign <id> --agent <tool>-explorer
```

### 3. Advance / rewind a ticket manually

```bash
multica-flow next MUL-142          # current phase done → move to next
multica-flow rewind MUL-142        # send back to phase:work (used after review/QA failures)
multica-flow status MUL-142        # show phase, state, last comment, attempt count
```

In normal operation you don't call `next` / `rewind` yourself — **the agents do it** as the last action of each turn, by writing the right `multica issue label / status / assign` calls. The CLI is for fixups.

## Per-phase prompts

Each phase has a prompt template under [`lanes/`](lanes/) that the corresponding agent's **system instructions** should point to. Recommended setup:

```bash
SYS=$(cat lanes/01-explore.md)
multica agent create --slug claude-explorer --tool claude-code \
  --system-instructions "$SYS" \
  --custom-args '["--max-turns","30"]'
```

The prompts use `{{ ticket.id }}`, `{{ attempt }}`, `{{ is_rewind }}` placeholders. The `multica-flow` CLI renders them when assigning, or — simpler — the prompt template itself instructs the agent to read those fields from `multica issue get $TICKET_ID` at start.

Lane files:

- [`lanes/00-base.md`](lanes/00-base.md) — common preamble (referenced by all phases)
- [`lanes/01-explore.md`](lanes/01-explore.md)
- [`lanes/02-work.md`](lanes/02-work.md)
- [`lanes/03-review.md`](lanes/03-review.md)
- [`lanes/04-qa.md`](lanes/04-qa.md)
- [`lanes/05-learn.md`](lanes/05-learn.md)

## Rewind semantics

Symphony's key insight: **don't fix Review/QA findings inside the same context that found them.** A fresh `phase:work` turn:

1. Reads `## Review Findings` or `## QA Failure` from the ticket comments.
2. Addresses ONLY those items.
3. Writes a new `## Implementation` comment with the delta.
4. Sets `phase:review` again. (Loop.)

The CLI scripts implement this:

```bash
multica-flow rewind MUL-142 --reason "review:CRITICAL"
# = multica issue label MUL-142 --remove phase:review --add phase:work
#   multica issue status MUL-142 --set in_progress
#   multica issue assign MUL-142 --agent claude-implementer
#   multica issue comment MUL-142 "rewind to phase:work (attempt $N) — see ## Review Findings"
```

After **3 consecutive QA failures**, the loop breaks: state→`blocked`, all phase labels removed, a human is `@`-mentioned via comment. Count is tracked in ticket comments (`## QA Failure #N`).

## Why labels, not states?

Multica states are fixed (`backlog/todo/in_progress/in_review/done/blocked/cancelled`) — you cannot add `phase-explore` as a state. Labels give us the orthogonal axis:

- **State** = "where in the macro flow is this ticket?" — used by Multica's own UI and reporting.
- **Phase label** = "which prompt do I run next?" — used by this skill.

A ticket in `in_progress + phase:work` and one in `in_progress + phase:review` look the same to Multica's progress chart but route to entirely different agents.

## When to use a different design

This pipeline is opinionated. Reach for it when:

- You have **non-trivial features** (>30 min of agent work) where review/QA pays back.
- You want **fresh-context turns** to dodge context-window pollution.
- You want **traceable artifacts** in the ticket itself (no separate doc system needed).

Skip it for:

- Single-line fixes, doc typos, dependency bumps — just assign directly to one agent.
- High-volume mechanical tasks — use Multica's `autopilot` with one tool.

## See also

- [`multica`](../multica/SKILL.md) — underlying CLI commands
- [`multica-onboarding`](../multica-onboarding/SKILL.md) — installs default skills used by phase agents
- [`docs/WORKFLOW.md`](../../docs/WORKFLOW.md) — full state diagram and rationale
- [`examples/csv-export-walkthrough.md`](../../examples/csv-export-walkthrough.md) — end-to-end
