# The Multica coding pipeline

A multi-phase pipeline — **explore → work → review → qa → learn** — layered on
Multica's fixed states. Each phase runs a purpose-built agent in a **fresh
context**; review/qa failures **rewind to work** instead of corrupting one long
session. Ported from [symphony-multi-agent](https://github.com/cskwork/symphony-multi-agent).

## How it maps onto Multica

Multica's states are fixed (`backlog todo in_progress in_review done blocked
cancelled`) and there is **no label-setting CLI command**. So the phase lives in
`metadata` under `pipeline_status`, and you move `status` + reassign as you go:

| Phase | `metadata pipeline_status` | `status` | Agent's job |
|-------|----------------------------|----------|-------------|
| explore | `explore` | `in_progress` | Read ticket + repo. Produce a **Domain Brief** + 2–3 plan candidates. **No code.** |
| work | `work` | `in_progress` | Implement the chosen plan. Open/update a PR (issue key in title/body). |
| review | `review` | `in_review` | Read the diff. Post findings by severity. CRITICAL/HIGH/MEDIUM → rewind. |
| qa | `qa` | `in_review` | Run tests / acceptance checks. Fail → rewind with `## QA Failure`. |
| learn | `learn` | `done` | Extract a reusable skill / note; close out. |

```
explore ─▶ work ─▶ review ─▶ qa ─▶ learn ─▶ done
   ▲                  │        │
   └──── rewind ◀──────┴────────┘     review or qa finds a problem → back to work
```

## Why phases beat one long run

A single agent that explores, codes, reviews, and QAs its own work in one context
grades its own homework — it rationalizes its earlier choices. Separate agents
with fresh context each phase means the reviewer hasn't already decided the code
is correct, and a rewind genuinely re-attempts rather than patching over.

## Per-phase agent instructions (wire once, reuse)

Create one agent per phase (`<tool>-explorer`, `<tool>-implementer`,
`<tool>-reviewer`, `<tool>-qa`) with system instructions roughly:

- **explorer** — "Read the ticket, repo, and any linked docs. Output a Domain Brief (what exists, constraints) and 2–3 plan candidates with trade-offs. Do NOT write code."
- **implementer** — "Implement the selected plan. Keep changes surgical. Open or update a PR with the issue key in the title or body. Report the PR URL in your final comment."
- **reviewer** — "Review the diff only. Post findings as `## Review Findings` with severity CRITICAL/HIGH/MEDIUM/LOW. Don't edit code."
- **qa** — "Run the tests and acceptance criteria. On failure, post `## QA Failure` with the exact failing output. Don't fix code."

Reusable across every ticket — phases are roles, not per-ticket agents.

## Advance one phase (copy-paste)

```bash
# advance.sh — move an issue to the next phase and dispatch the next agent
issue="$1"; next="$2"; agent="$3"          # e.g. ./advance.sh MUL-142 work codex-implementer
case "$next" in
  explore|work) status=in_progress ;;
  review|qa)    status=in_review ;;
  learn)        status=in_review ;;
  *) echo "unknown phase: $next" >&2; exit 1 ;;
esac
multica issue metadata set "$issue" --key pipeline_status --value "$next"
multica issue status "$issue" "$status"
multica issue assign "$issue" --to "$agent"
echo "→ $issue now in $next ($status), assigned $agent"
```

## Rewind on failure (review/qa → work)

```bash
# rewind.sh — bounce a failed ticket back to the implementer with fresh context
issue="$1"; agent="$2"; reason="$3"        # e.g. ./rewind.sh MUL-142 codex-implementer "QA: 2 tests red"
multica issue comment add "$issue" --content "## Rewind to work
$reason
Fix only what's listed above; re-open/update the PR."
multica issue metadata set "$issue" --key pipeline_status --value work
multica issue status "$issue" in_progress
multica issue assign "$issue" --to "$agent"
```

The implementer reads the `## Review Findings` / `## QA Failure` comment and fixes
**only** those, then the ticket flows forward again.

## Stuck-ticket guard

Track repeated failures with metadata so a ticket can't loop forever:

```bash
# on each qa failure
n=$(( $(multica issue metadata get "$issue" --key qa_fails 2>/dev/null || echo 0) + 1 ))
multica issue metadata set "$issue" --key qa_fails --value "$n" --type number
if [ "$n" -ge 3 ]; then
  multica issue status "$issue" blocked
  multica issue subscriber add "$issue" --user "<human-owner>"
  multica issue comment add "$issue" --content "Blocked after 3 QA failures — needs a human. @<human-owner>"
fi
```

Reset `qa_fails` to 0 when QA passes.

## Driving it

- **Manual / scripted** — run `advance.sh` / `rewind.sh` at each gate from your shell or CI.
- **Autonomous** — give each phase agent the instructions above and let the daemon
  dispatch; the agent itself runs the advance/rewind commands (it has `Bash(multica *)`)
  as the last step of its turn, handing off to the next phase.
- **Scheduled sweeps** — an autopilot can drain a phase nightly:
  `multica autopilot create --title "Nightly: advance review→qa" --agent <qa> --mode run_only`
  plus a cron trigger (`multica autopilot trigger-add … --cron "0 2 * * *"`).

## Worked example

```bash
# 1. Create + start exploring
ID=$(multica issue create --title "Add CSV export to /reports" --priority high \
       | grep -oE 'MUL-[0-9]+' | head -1)
multica issue metadata set "$ID" --key pipeline_status --value explore
multica issue assign "$ID" --to claude-explorer        # daemon runs it; it writes a Domain Brief

# 2. Explorer done → advance to work
./advance.sh "$ID" work codex-implementer

# 3. Implementer opens a PR → advance to review, then qa
./advance.sh "$ID" review claude-reviewer
multica issue pull-requests "$ID" --output json         # check the linked PR's state/checks

# 4a. QA passes → learn → done
./advance.sh "$ID" learn claude-explorer
multica issue status "$ID" done

# 4b. QA fails → rewind
./rewind.sh "$ID" codex-implementer "## QA Failure: export streams empty on 100k rows"
```

See `references/cli-reference.md` for every command used here.
