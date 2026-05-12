# Walkthrough — "Add CSV export to /reports"

A fictional but realistic ticket walked end-to-end through the multica-workflow pipeline. Every command is real; the responses are illustrative.

## Setup (one-time)

```bash
# Install the bundle for your harness
git clone https://github.com/cskwork/multica-skill ~/.multica-skill
cd ~/.multica-skill && ./install.sh
export PATH="$HOME/.multica-skill/bin:$PATH"

# Inside Claude Code (or any harness):
/multica-onboarding              # registers superpowers + playwright + atlassian-cli

# Bootstrap the role agents (creates 5 agents in Multica, one per phase)
multica-flow bootstrap
# → creates: claude-explorer, claude-implementer, claude-reviewer, claude-qa, claude-learner
```

## Step 1 — File the ticket

```bash
$ multica-flow new "Add CSV export to /reports"
Created MUL-142
  status: todo
  labels: phase:explore
  assignee: (none)
→ MUL-142 dispatched to claude-explorer
```

Multica's daemon picks this up within ~3s and starts `claude-explorer` against `MUL-142`.

## Step 2 — Explore phase (automatic)

`claude-explorer` reads:

- the ticket title + body (which only said "Customers want to export the reports table as CSV; <5s for 100k rows")
- `src/reports/` (existing report code)
- `src/users/list.ts` (a streaming endpoint that already exists — good reference)
- `docs/database.md`

It comments:

```markdown
## Domain Brief
- /reports already serves JSON via `src/reports/router.ts:14` (`/reports/data`).
- The repo uses `csv-stringify` only in scripts/seed-fixtures.ts; not in the app code yet.
- `src/users/list.ts:18` streams via `db.query(sql, params, {stream:true})` returning a cursor; that's the pattern to copy.
- No existing perf test for streaming endpoints; the closest is `tests/perf/list-users.bench.ts`.

## Plan Candidates
### A — New endpoint `/reports/export?format=csv` (recommended)
- File: new `src/reports/export.ts`; mount in `router.ts`.
- Stream cursor → `csv-stringify` → response.
- Tests: unit for serializer + perf test (<5s, 100k rows).
- Risk: low; isolated.

### B — Add `?format=csv` to existing `/reports/data`
- Cleaner URL, but breaks the implicit JSON contract for current consumers.
- Risk: medium (compatibility).

## Recommendation
**Pick: A.** Add `/reports/export?format=csv`. Mirror `src/users/list.ts:18`'s streaming pattern. Add a 100k-row fixture (`fixtures/large/reports.json`, generated) and a perf test that fails if response time exceeds 5s.
```

Then:

```bash
multica issue label  MUL-142 --remove phase:explore --add phase:work
multica issue status MUL-142 --set in_progress
multica issue assign MUL-142 --agent claude-implementer
```

## Step 3 — Work phase (automatic)

`claude-implementer` starts. It:

1. Creates worktree: `git worktree add ../wt-MUL-142 -b multica/MUL-142`
2. Writes a failing test for the happy path
3. Implements `src/reports/export.ts` mirroring `users/list.ts`
4. Adds the perf test (fails if >5s on 100k-row fixture)
5. Runs `npm test` — green
6. Commits with `feat: add CSV export to /reports (MUL-142)`

Comments:

```markdown
## Implementation
Branch: `multica/MUL-142`
Commits:
- `abc123` feat: add /reports/export endpoint with CSV streaming
- `def456` test: cover empty + 100k-row + invalid-format cases
Files: src/reports/export.ts (new, 71 lines), src/reports/router.ts (+8), tests/reports/export.test.ts (new), tests/perf/export.bench.ts (new)

How to run:
  npm install
  npm test -- reports/export
  npm run perf:export    # 100k-row check
```

Hand-off to `phase:review`.

## Step 4 — Review phase (automatic)

`claude-reviewer` checks out the branch, reads the diff, runs tests.

It finds:

```markdown
## Review Findings
### CRITICAL
(none)
### HIGH
1. `src/reports/export.ts:42` — `req.query.filter` is concatenated into the SQL string. Use parameterized query like `src/users/list.ts:24`.
### MEDIUM
(none)
### LOW
1. Import order at top of export.ts.

### Verdict
REWIND to phase:work.
```

```bash
multica-flow rewind MUL-142 --reason "review:HIGH SQL injection"
```

## Step 5 — Work phase (rewind, attempt 2)

`claude-implementer` re-enters, fresh context. Reads `## Review Findings`. Fixes the SQL injection. Writes:

```markdown
## Implementation (rewind attempt 2)
Commits:
- `0fa7c1` fix: parameterize filter query (review HIGH #1)
- `1bb44e` chore: reorder imports (review LOW #1)
```

Hand-off to `phase:review` again.

## Step 6 — Review (clean)

`claude-reviewer` re-grades. Finds nothing CRITICAL/HIGH/MEDIUM. Hands off to `phase:qa`.

## Step 7 — QA phase (automatic)

`claude-qa` starts the dev server, runs:

- `curl /reports/export?format=csv | head -3` — passes
- `time curl /reports/export?format=csv | wc -l` — 3.41s for 100k rows ✅
- empty filter — returns just header row ✅
- `?format=xml` — returns 400 ✅
- Playwright spec (`e2e/specs/MUL-142.spec.ts`) — passes, trace attached

```markdown
## QA Evidence
[as in lanes/04-qa.md]
### Verdict
ADVANCE to phase:learn.
```

Hand-off to `phase:learn`.

## Step 8 — Learn phase (automatic)

`claude-learner` reads the whole ticket, identifies:

```markdown
## Learnings
1. Streaming queries require `db.query(sql, params, {stream:true})` — the array-return path will OOM at 100k+ rows. Document in `docs/database.md`.
2. Acceptance criteria with latency thresholds need explicit perf tests; unit tests don't time-box.
3. Reusable 100k-row fixture committed at `fixtures/large/reports.json`; generation script at `scripts/gen-large-fixtures.ts`.

## Wiki Updates
- `docs/database.md` — added "Streaming queries" section (commit `f00ba2`)
- `CLAUDE.md` — added "When ticket has a latency threshold, write a perf test" rule (commit `f00ba3`)
```

```bash
multica issue label  MUL-142 --remove phase:learn
multica issue status MUL-142 --set done
multica issue comment MUL-142 "✅ pipeline complete"
```

## End state

```bash
$ multica-flow status MUL-142
MUL-142 — Add CSV export to /reports
  status: done
  labels: (none)
  branch: multica/MUL-142
  comments:
    ## Domain Brief        (claude-explorer)
    ## Plan Candidates     (claude-explorer)
    ## Recommendation      (claude-explorer)
    ## Implementation      (claude-implementer)
    ## Review Findings     (claude-reviewer)
    ## Implementation (rewind attempt 2)  (claude-implementer)
    ## Review Findings (clean)  (claude-reviewer)
    ## QA Evidence         (claude-qa)
    ## Learnings           (claude-learner)
    ## Wiki Updates        (claude-learner)
```

Time on the wall: ~25 minutes of agent work for a 70-line feature with a security rewind, an integration test, a perf test, real browser QA evidence, and two wiki updates.

The human who filed `MUL-142` looked at it once, when it was done.
