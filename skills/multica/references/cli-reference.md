# multica CLI reference

Every `multica` command by area, with the exact flags documented in the official
`CLI_AND_DAEMON.md` and `docs/cli`. When a command's detailed flags aren't
documented, the entry says so — run `multica <command> --help` for the truth.

Config lives at `~/.multica/config.json`. List commands print short, copy-paste
IDs (issue keys like `MUL-123`, short UUID prefixes for the rest); pass
`--full-id` for canonical UUIDs. Most read commands accept `--output table|json`.

---

## Auth & setup

```bash
multica login                       # browser flow; saves a PAT (mul_…), valid 90 days
multica login --token <mul_…>       # headless/CI; PAT from web app → Settings → Personal Access Tokens
multica auth status                 # current user + token validity + workspace
multica auth logout                 # clear the local PAT

multica setup                       # Cloud: configure + login + start daemon, one shot
multica setup self-host             # same, against a self-hosted server
multica setup self-host --server-url https://api.example.com --app-url https://app.example.com
multica setup self-host --port 9090 --frontend-port 4000
multica setup self-host --profile staging --server-url … --app-url …   # isolate orgs with profiles
```

## Daemon

The daemon registers your machine as a **runtime**, detects installed AI CLIs,
polls the server (default 3s) for claimed tasks, and runs them.

```bash
multica daemon start                # background; logs to ~/.multica/daemon.log
multica daemon start --foreground   # run in foreground (debugging)
multica daemon stop
multica daemon restart
multica daemon status [--output json]
multica daemon logs                 # view daemon logs
```

Detected agent CLIs on `PATH`: `claude`, `codex`, `copilot`, `openclaw`,
`opencode`, `hermes`, `gemini`, `pi`, `cursor-agent`, `kimi`, `kiro-cli`, `agy`.

## Workspaces & members

```bash
multica workspace list [--full-id] [--output json]    # current marked with *
multica workspace get <id|slug> [--output json]        # no arg → current workspace
multica workspace member list <workspace-id> [--output json]
multica workspace switch <id|slug>                     # day-to-day way to change default workspace
multica workspace update <id> --name "Eng" [--description "…"] [--context "…"] [--issue-prefix "ENG"]
#   long fields also accept --description-stdin / --context-stdin
```

For scripting prefer `--workspace-id` / `MULTICA_WORKSPACE_ID`; `multica config
set workspace_id <id>` is the low-level equivalent of `switch`.

## Issues

```bash
# List + filter
multica issue list
multica issue list --status in_progress --priority urgent --assignee "Lambda"
multica issue list --assignee-id <uuid> --project <id> --limit 50
multica issue list --metadata pipeline_status=review --metadata pr_number=482
#   --metadata values are JSON-parsed: true/false→bool, 42→number; wrap '"42"' to force a string

multica issue get <id>                  # short key (MUL-123) or full UUID
multica issue search "csv export"

# Create — flags: --title (required) --description --status --priority
#                 --assignee | --assignee-id --parent --project --due-date
multica issue create --title "Fix login bug" --priority high --assignee "Lambda"
multica issue create --title "…" --description-stdin <<'EOF'
Multi-line body via stdin.
EOF
multica issue create --title "Step 2" --parent <issue-id> --assignee <agent> --status backlog

multica issue update <id> --title "New title" --priority urgent

# Assign / dispatch an existing issue
multica issue assign <id> --to "Lambda"      # or --to-id <uuid>, or --unassign

# Status — positional arg, any → any of: backlog todo in_progress in_review done blocked cancelled
multica issue status <id> in_progress

# Comments
multica issue comment list <issue-id> [--recent 20] [--thread <comment-id> --tail 30]
multica issue comment add <issue-id> --content "Looks good, merging now"
multica issue comment add <issue-id> --parent <comment-id> --content "Thanks!"
multica issue comment delete <comment-id>

# Subscribers (notifications); without --user, acts on the caller
multica issue subscriber list <issue-id>
multica issue subscriber add <issue-id> [--user "Lambda"]
multica issue subscriber remove <issue-id> [--user "Lambda"]

# Metadata — durable per-issue state; single-key atomic writes
multica issue metadata list <issue-id>
multica issue metadata get <issue-id> --key pipeline_status
multica issue metadata set <issue-id> --key pipeline_status --value review
multica issue metadata set <issue-id> --key code --value 42 --type string   # force a type
multica issue metadata delete <issue-id> --key pipeline_status

# Execution history & linked PRs
multica issue runs <issue-id> [--full-id] [--output json]
multica issue run-messages <task-id> [--issue <issue-id>] [--since 42] [--output json]
multica issue rerun <id>                 # re-enqueue a fresh task for the current assignee
multica issue pull-requests <issue-id> --output json
#   each PR: state(merged|closed|draft|open), merged_at, mergeable_state, checks_conclusion
```

High-signal metadata keys (reuse the names): `pr_url`, `pr_number`,
`pipeline_status`, `deploy_url`, `external_issue_url`, `waiting_on`,
`blocked_reason`, `decision`. Logs, summaries, and notes belong in a comment, not metadata.

## Projects

```bash
multica project list [--status in_progress] [--output json]
multica project get <id>
multica project create --title "2026 Week 16 Sprint" [--description "…"] [--icon "🏃"] [--lead "Lambda"]
multica project update <id> --title "New title" [--lead "Lambda"] [--status …]
multica project status <id> in_progress    # planned | in_progress | paused | completed | cancelled
multica project delete <id>
# Associate issues with --project on issue create/update
```

## Agents

Required to create: **a name** and **a runtime** (which AI coding tool). Every
other field is optional and changeable later — the exact CLI flags vary, so run
`multica agent create --help`.

```bash
multica agent list [--output json]
multica agent get <slug>
multica agent create               # name + runtime required; see --help for optional flags
multica agent update <slug> …
multica agent archive <slug>       # cancels the agent's unfinished tasks immediately
multica agent restore <slug>
multica agent tasks <slug>         # task history
multica agent skills …             # nested: attach / detach skills
multica agent env get <id>         # owner/admin only; reveal custom_env values (audited)
```

Optional agent fields (from the web form / API): system **instructions**
(prepended to every task), **model**, **custom_env** (extra env vars; `PATH`,
`HOME`, `USER`, `SHELL`, `TERM`, `CODEX_HOME`, `MULTICA_*` are ignored), **custom_args**
(string array appended to the tool's command line), **visibility**
(`workspace` | `private`, default `private`), **max_concurrent_tasks** (default 6).
Keep custom_env/custom_args under ~10 entries each. Secrets in custom_env are
stored plaintext server-side — use limited-scope credentials.

## Skills

```bash
multica skill list
multica skill get <name>
multica skill create …
multica skill update <name> …
multica skill delete <name>
multica skill files …                                  # nested: manage a skill's files
multica skill import --url https://github.com/owner/repo            # GitHub
multica skill import --url https://skills.sh/acme/repo/review-helper
#   also: ClawHub (claw://…) and local-directory scans
```

Import conflict handling (default `--on-conflict fail`):

```bash
multica skill import --url <url> --on-conflict overwrite   # replace, keep ID + agent bindings
multica skill import --url <url> --on-conflict rename      # import a copy with a -2 suffix
multica skill import --url <url> --on-conflict skip        # leave existing untouched
```

A skill must be **attached to an agent** to take effect; it's delivered to the
tool's skill path at the next task. Multica adopts the Anthropic Agent Skills
standard. Review third-party skills before importing — Multica does not sandbox them.

## Squads

A squad routes work to a group led by an agent; the leader delegates. Detailed
flags vary — use `--help`.

```bash
multica squad list
multica squad get <id>
multica squad create --name "FrontendTeam" --leader <agent>     # owner / admin
multica squad update <id> …                                     # name, description, instructions, leader, avatar
multica squad delete <id>                                       # soft-delete; reassigns issues to the leader
multica squad member list|add|remove|set-role <squad-id> …
multica squad activity <issue-id> <action|no_action|failed> --reason "…"   # leader records a per-turn evaluation
```

## Autopilots

Scheduled / triggered automations that run an agent.

```bash
multica autopilot list [--full-id] [--status active] [--output json]
multica autopilot get <id> [--output json]               # --output json includes triggers
multica autopilot create --title "Nightly bug triage" --description "Scan todo issues." \
  --agent "Lambda" --mode create_issue
#   --mode: create_issue (new issue each run, assigned to the agent) | run_only (direct task, no issue)
#   --agent: name or UUID
multica autopilot update <id> --status paused
multica autopilot update <id> --description "New prompt"
multica autopilot delete <id>
multica autopilot trigger <id>                           # fire once, returns the run
multica autopilot runs <id> [--limit 50] [--output json]

# Schedule triggers (only cron 'schedule' triggers are exposed via CLI)
multica autopilot trigger-add <autopilot-id> --cron "0 9 * * 1-5" --timezone "America/New_York"
multica autopilot trigger-update <autopilot-id> <trigger-id> --enabled=false
multica autopilot trigger-delete <autopilot-id> <trigger-id>
```

## Runtimes

```bash
multica runtime list                  # runtimes in the current workspace (status, provider, device)
multica runtime usage                 # token/$ accounting per runtime
multica runtime activity              # recent activity log
multica runtime update <id> …         # update a runtime's configuration
```

## Miscellaneous

```bash
multica repo checkout <url>           # clone a repo locally for agents to use
multica config show
multica config set server_url https://api.example.com
multica config set app_url https://app.example.com
multica config set workspace_id <workspace-id>     # low-level; prefer `workspace switch`
multica attachment download <id>      # download an attachment from an issue or comment
multica version                       # CLI version + commit hash
multica update                        # upgrade to the latest release (auto-detects install method)
```

## Output formats & environment

- `--output table` (default, human-readable) or `--output json` (structured) on most read commands.
- `MULTICA_HTTP_TIMEOUT` — API timeout (default 30s); accepts Go duration (`45s`, `2m`) or seconds (`45`).
- `MULTICA_WORKSPACE_ID` — target workspace without switching the default.
- `MULTICA_DAEMON_POLL_INTERVAL` (3s), `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` (20), `MULTICA_DAEMON_ID`, `MULTICA_WORKSPACES_ROOT`.
- `MULTICA_GC_ENABLED` (true), `MULTICA_GC_INTERVAL` (1h), `MULTICA_GC_ORPHAN_TTL` — orphaned-workspace cleanup.
- `MULTICA_<PROVIDER>_PATH` / `MULTICA_<PROVIDER>_MODEL` — override a tool's binary or model (e.g. `MULTICA_CLAUDE_PATH`, `MULTICA_KIMI_MODEL`).
- `MULTICA_CLAUDE_ARGS` / `MULTICA_CODEX_ARGS` — extra args, parsed with POSIX shellword quoting.

Errors pass through one friendly translation layer: a 401 tells you to run
`multica login`; a timeout suggests raising `MULTICA_HTTP_TIMEOUT`.
