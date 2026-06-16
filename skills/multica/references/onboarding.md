# Onboarding a machine to Multica

Goal: from nothing to an agent picking up its first task. Five steps. Commands
match the official `multica` README and `docs/cli`.

## 1. Install the CLI

```bash
# macOS / Linux (Homebrew, recommended)
brew install multica-ai/tap/multica
brew upgrade multica-ai/tap/multica          # keep current

# macOS / Linux (install script — when Homebrew isn't available)
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex
```

Verify: `which multica && multica version`.

You also need at least one supported AI coding tool on your `PATH` (e.g.
`claude`, `codex`, `cursor-agent`, `gemini`, `copilot`) — that's what the daemon
actually runs.

## 2. Configure, authenticate, and start the daemon

```bash
multica setup          # one shot: configure + browser login (saves PAT) + start daemon
multica auth status    # confirm user + workspace
```

`setup` opens your browser; approve in the web app and the PAT (`mul_…`) is saved
to `~/.multica/config.json`. Headless/CI instead: create a PAT under **Settings →
Personal Access Tokens** and run `multica login --token <mul_…>`.

## 3. Verify your runtime

The daemon registers your machine as a **runtime** and reports which AI CLIs it
found. Confirm it's online:

```bash
multica daemon status
multica runtime list      # your machine should appear, STATUS online, with its detected providers
```

Or in the web app: **Settings → Runtimes**. A runtime is just a compute
environment (your laptop via the daemon, or a cloud instance) that can execute
agent tasks — Multica routes work to wherever the right tool is available.

## 4. Create an agent

An agent = one AI coding tool + a name (+ optional instructions/model/skills).
Required: **name** and **runtime/tool**; everything else is optional and editable later.

```bash
multica agent create        # interactive / flag-driven — see `multica agent create --help`
multica agent list          # confirm it exists with a slug and provider
```

Or in the web app: **Settings → Agents → + New**, pick the runtime you just
connected, choose a provider (Claude Code is the best first pick), name it.

Give it system instructions to scope its role, e.g. *"You're a frontend
review agent — read the diff, leave suggestions in a comment, don't change code."*

## 5. Assign the first task

```bash
ID=$(multica issue create --title "Smoke test: say hello in a comment" --assignee "<agent-name>" \
       | grep -oE 'MUL-[0-9]+' | head -1)
multica issue get "$ID"            # watch status + comments
multica daemon logs                # watch the run
```

Creating with `--assignee` at a non-`backlog` status dispatches immediately. The
agent claims the task on your runtime and reports back on the issue — like a
human teammate.

## Self-hosting (optional)

```bash
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash -s -- --with-server
multica setup self-host                                   # connect the CLI to your server
# or point at an existing one:
multica setup self-host --server-url https://api.example.com --app-url https://app.example.com
```

Pulls official images from GHCR (requires Docker). If a tag isn't published yet,
fall back to `make selfhost-build` from a checkout. See the project's
`SELF_HOSTING.md` for details.

## Optional: bootstrap default skills

Import reusable skill bundles so every agent starts with shared know-how:

```bash
multica skill import --url https://github.com/cskwork/multica-skill    # this bundle (multica CLI + workflow)
multica skill list | grep multica
multica agent skills <agent-slug>      # attach it (nested command — see --help)
```

Other community picks teams commonly add: superpowers, an Atlassian/Jira CLI
skill, a Playwright testing skill — import each the same way, then attach to the
agents that need them. Review any third-party skill before importing (Multica
does not sandbox skill contents).

## Where to go next

- Run a real pipeline → `references/workflow.md`
- Full command set → `references/cli-reference.md`
