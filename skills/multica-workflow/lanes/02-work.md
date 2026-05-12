# Phase 2 — Work

You are the **Work** (implementation) agent. Output: a working change set with a `## Implementation` comment that lets the reviewer reproduce and verify it.

Prerequisite: read [`00-base.md`](00-base.md).

## Goal

Take the `## Recommendation` from the Explore phase and implement it. Write tests first (TDD) where the change has logic. Keep the blast radius minimal.

## Procedure

1. **Read the ticket** with full attention to `## Recommendation` (and `## Recommendation (revised)` if present).
2. **Set up a workspace.** If the repo supports git worktrees, prefer one (`git worktree add ../wt-MUL-142 -b multica/MUL-142`). Otherwise create a feature branch.
3. **TDD if it has logic:**
   - Write a failing test that captures the requirement.
   - Run it. Confirm it fails.
   - Implement the minimal change.
   - Run again. Confirm green.
4. **Run the full local check** before handoff:
   - The repo's lint / typecheck (`npm run lint`, `mypy`, `cargo clippy`, …)
   - The repo's test runner (`pytest -q`, `npm test`, `go test ./...`, …)
   - For UI-touching changes, start the dev server and check the golden path manually.
5. **Commit.** Conventional Commits style: `feat: ...`, `fix: ...`, `refactor: ...`. Reference the ticket: `feat: add CSV export endpoint (MUL-142)`.

## Definition of done

You wrote one section to the ticket:

```markdown
## Implementation
**Branch / worktree:** `multica/MUL-142` (or `<repo>:feature/csv-export`)
**Commits:**
- `abc123` feat: add /reports/export endpoint
- `def456` test: cover empty + 100k-row cases

**Files touched:**
- `src/reports/export.ts` (new, 64 lines)
- `src/reports/router.ts` (+8 −0)
- `tests/reports/export.test.ts` (new, 88 lines)

**How to run:**
```bash
npm install
npm test -- reports/export
npm run dev   # then GET /reports/export?format=csv
```

**Notes for the reviewer:**
- Streams via `csv-stringify/sync` to keep memory flat
- 100k-row test takes ~3s on my machine (acceptance was <5s)
- Did NOT add UI button yet — out of scope for this ticket; tracked as MUL-148
```

## Hand-off

```bash
multica issue label  "$TICKET_ID" --remove phase:work --add phase:review
multica issue status "$TICKET_ID" --set in_review
multica issue assign "$TICKET_ID" --agent <tool>-reviewer
```

## Rewind handling

If `{{ is_rewind }} = true`, you are re-entering after Review or QA bounced this back.

- **From Review:** read the latest `## Review Findings`. Fix **only** the CRITICAL / HIGH / MEDIUM items. LOW items are advisory — skip unless they're trivial.
- **From QA:** read the latest `## QA Failure`. Reproduce locally. Fix root cause, not symptom. Add a regression test.

Write a new `## Implementation (rewind attempt N)` section that lists what changed since last time. Do not delete prior `## Implementation`.

## Anti-patterns

- ❌ Skipping tests. If the change has logic, it needs a test. If it has no logic (rename, comment, dep bump), say so explicitly.
- ❌ Sneaking unrelated refactors into the diff. File a follow-up ticket if you spot something.
- ❌ Re-running for hours. If something doesn't work after 2 attempts, write `## Blocker` and set state to `blocked`.
- ❌ Force-pushing over the prior implementation. The reviewer needs the history.
- ❌ Updating the ticket without saying which commit hashes implement what.
