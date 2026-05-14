# Sequential dispatch — running 80+ issues in strict order

Multica's daemon picks the next agent task by

```sql
ORDER BY agent_task_queue.priority DESC, agent_task_queue.created_at ASC
LIMIT 1
```

so a bulk import where higher-difficulty tickets carry `priority high` will silently jump ahead of `priority medium` setup work. This page collects the patterns we found while running an 86-issue feature spec through a single board.

## TL;DR

If you want **T001 → T002 → …** to run in order:

1. **Flatten priorities** at import time (or update after) so the queue ordering becomes pure FIFO on `created_at`.
2. Cap each agent: `multica agent update <id> --max-concurrent-tasks 1`.
3. **Hold the future work in a non-claimable status** (`backlog` or `cancelled`). Only the issue you want to run next stays in `todo`.
4. After each completion (status → `in_review` / `done`), promote the next issue from the holding pool back to `todo` and reassign it.
5. If a botched run already left zombies in `agent_task_queue`, drain them with `POST /api/agents/{id}/cancel-tasks` (see below). Flipping the underlying issue status alone does **not** cancel queued rows.

## Reference: claim semantics

`multica/server/server/pkg/db/queries/agent.sql`:

```sql
-- name: ClaimAgentTask :one
UPDATE agent_task_queue
SET status = 'dispatched', dispatched_at = now()
WHERE id = (
    SELECT atq.id FROM agent_task_queue atq
    WHERE atq.agent_id = $1 AND atq.status = 'queued'
      …
    ORDER BY atq.priority DESC, atq.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
RETURNING *;
```

Key takeaways:

- The claim path does **not** read `issue.status`. Moving an issue to `backlog` after assignment leaves its queue row claimable.
- `priority` is set at `agent_task_queue` insert time from the **issue's** priority enum. Updating the issue priority afterwards does not rewrite the queue rows.
- `FOR UPDATE SKIP LOCKED` means many daemons can drain in parallel safely, but the order across them is still per-priority FIFO.

## Single-flight loop

```python
# examples/strict-sequential.py – run once or with --watch
# Promotes the next holding (cancelled/backlog) issue to `todo` once the
# currently-active one reaches `in_review` or `done`.
```

The watcher also re-applies the desired agent owner per phase (claude-code for setup/foundation, codex for user-story implementation, etc.).

## Bulk-cancel the agent task queue

When `multica daemon start` keeps reviving long-dead work, the queue itself needs draining. The CLI doesn't expose this yet; the server route does:

```bash
TOK=mul_…                                    # PAT from `multica login`
WS=$(multica config show | awk '/workspace_id/{print $2}')
AGENT=$(multica agent list --output json | jq -r '.[] | select(.name=="claude-code") | .id')

curl -sS -X POST \
  -H "Authorization: Bearer $TOK" \
  -H "X-Workspace-ID: $WS" \
  http://localhost:9090/api/agents/$AGENT/cancel-tasks
# {"cancelled":N}
```

- Route prefix is `/api` (not `/api/v1`).
- `X-Workspace-ID` is required when using the CLI's workspace token; without it you'll get `workspace not found`.
- The response field `cancelled` is the number of `queued|dispatched|running` rows transitioned to `cancelled` — it does not include rows that were already terminal.

## Bulk import recipe

The shipping example `import-tasks-from-md.py` parses a markdown checklist (`tasks.md`) and creates one Multica issue per checkbox. Tweak these defaults the next time you import:

- Map all difficulties to `medium` priority unless something is genuinely a fire. The `phase:*` label is more useful for ordering than `priority`.
- Add a single setup comment on each issue with the working repo URL, so the agent's first turn doesn't trip on "no git repository in workdir".
- Hold everything but the first wave in `backlog` immediately after creation (the import script's `--hold-after-create` flag does this).

## Related

- `examples/strict-sequential.py` — single-flight promoter
- `examples/wave-promoter.py` — wave-based promotion (promote `phase:foundation` once all `phase:setup` are done, etc.)
- `examples/holdback-wave.py` — initial state setup: reset stuck issues + flatten priorities + hold future waves
- `examples/rebalance-by-phase.py` — reassign issues to the desired agent based on `phase:*` label, leaving issue status untouched
- `examples/import-tasks-from-md.py` — bulk-create issues from a tasks.md checklist

## Caveat: after `cancel-tasks`, you must re-enqueue assigned issues

`POST /api/agents/{id}/cancel-tasks` flips every `queued|dispatched|running` row to `cancelled` — including the row that was created by a previous `multica issue assign`. The assignment on the issue remains, but the queue has nothing for the daemon to claim, so the task **looks scheduled but never starts**.

Force a fresh queue row:

```bash
multica issue assign $ID --unassign
multica issue assign $ID --to claude-code
multica issue rerun $ID
```

The single-flight watcher in `examples/strict-sequential.py` does this on every promotion.
