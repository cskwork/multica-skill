# WORKFLOW.md

The full pipeline this skill drives. For the per-phase prompt content, see [`skills/multica-workflow/lanes/`](../skills/multica-workflow/lanes/).

## State machine

```
                            ┌────────────── ## Review Findings (C/H/M) ──────────────┐
                            │                                                        │
                            │             ┌────── ## QA Failure ───────┐              │
                            ▼             │                            │              │
 (created)
   │
   ▼
┌────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌──────┐
│ todo   │ ─▶ │  in_progress    │ ─▶ │  in_review      │ ─▶ │  in_review      │ ─▶ │  in_review      │ ─▶ │ done │
│ phase: │    │  phase:work     │    │  phase:review   │    │  phase:qa       │    │  phase:learn    │    │      │
│explore │    │                 │    │                 │    │                 │    │                 │    │      │
└────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘    └──────┘
   ▲              ▲     │                  │                    │
   │              │     │                  │ findings           │ failure (3× → blocked)
   │              │     └─ ## Blocker ─▶ blocked                │
   │              │                                              │
   │              └────────── rewind on review/qa failure ◀──────┘
```

## Why the macro states + label combo

Multica's state set is fixed at 7 values and **not user-extensible**: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`. We need 5 active phases. The natural mapping:

| Multica state | Active phase(s) inside it |
|---------------|---------------------------|
| `backlog`     | (untriaged) |
| `todo`        | `phase:explore` |
| `in_progress` | `phase:work` |
| `in_review`   | `phase:review` → `phase:qa` → `phase:learn` |
| `done`        | terminal success |
| `blocked`     | hard blocker (human action required) |
| `cancelled`   | won't fix / superseded |

Three lanes live inside `in_review`. That's intentional: Multica's progress reporting still treats them all as "ready for verification", which is correct — they're all post-implementation. The internal phase label tells our pipeline which agent runs next.

## Why the agent writes the next state

The Multica daemon is a **read-only orchestrator** — it polls boards, picks issues whose `assignee` matches an agent, runs that agent, and waits. The agent is the only actor that can decide "I'm done; the ticket should now be in `phase:review`." This matches Symphony's design (`tracker.py` only reads; agents write).

Concretely, the last shell calls of every phase agent's turn are:

```bash
multica issue comment "$ID" "## <Section>\n<contents>"     # add evidence
multica issue label   "$ID" --remove phase:<cur> --add phase:<next>
multica issue status  "$ID" --set <next-state-if-changing>
multica issue assign  "$ID" --agent <next-agent>          # triggers next run
```

`multica issue assign` is the dispatch event. The daemon's next poll picks it up and starts the named agent.

## Rewind logic

Severity is **agent-authored, label-tracked**. Review and QA write graded findings into ticket comments using the headings:

- `## Review Findings` with `### CRITICAL`, `### HIGH`, `### MEDIUM`, `### LOW`
- `## QA Failure #N` (sequential — count the existing ones)

The rewind decision lives inside the Review/QA agent's prompt (see [`lanes/03-review.md`](../skills/multica-workflow/lanes/03-review.md) and [`lanes/04-qa.md`](../skills/multica-workflow/lanes/04-qa.md)). The CLI is a backup for manual fixups: `multica-flow rewind <id>`.

## Three-strikes rule

If a ticket has accumulated `## QA Failure #1`, `## QA Failure #2`, `## QA Failure #3`, the QA agent escalates instead of rewinding: state→`blocked`, all phase labels removed, `@human` mention in a comment.

Tunable via `qa_failure_limit` in `templates/workflow.yaml`.

## Concurrency

Multica's daemon defaults: 20 concurrent tasks globally (`MULTICA_DAEMON_MAX_CONCURRENT_TASKS`), and each agent has its own `max_concurrent_tasks` (default 6). Setting a per-phase agent's concurrency to 1 turns that phase into a serial bottleneck — useful for QA where you want sequential evidence runs, less useful for explore/review where parallel reads are fine.

## What this does NOT do

- It does **not** open PRs automatically. The `## Learnings` phase can do `gh pr create` if you want — see [`lanes/05-learn.md`](../skills/multica-workflow/lanes/05-learn.md).
- It does **not** modify the repo outside the agent's turn. The agent itself does all git operations within its Multica-managed workspace.
- It does **not** depend on a separate orchestrator process. Multica's daemon is the orchestrator.

## Comparing to Symphony

| Symphony | multica-skill | Notes |
|----------|---------------|-------|
| Custom lane state (Todo/Explore/In Progress/Review/QA/Learn/Done) | Multica fixed state + `phase:*` label | Multica states are not user-customizable; we encode phases in labels. |
| Polling orchestrator (`symphony tui`) | Multica daemon | Same shape: read-only, polls, dispatches. |
| Per-ticket git worktree via hooks | Agent-driven worktree (in Work phase) | Multica doesn't yet have first-class worktree hooks; the agent does `git worktree add` itself. |
| Exponential backoff retry | Multica's daemon retry + 3-strikes blocked | Multica handles transient failures; our pipeline handles semantic failures. |
| Linear / file tracker | Multica board | Same role; native APIs differ. |
| Liquid templates for prompts | Plain markdown the agent reads at turn start | Multica has no template engine; the agent reads ticket context itself. |
