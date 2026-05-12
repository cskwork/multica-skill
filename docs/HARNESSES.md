# HARNESSES.md

Where each harness reads skills from, and how `adapters/` wires this bundle in.

## The lowest common denominator

Every supported harness reads **markdown with YAML frontmatter** for skill definition. Frontmatter we use:

```yaml
---
name: <skill-name>
description: <when to trigger>
---
```

Two required fields, both string. This matches obra/superpowers' minimal schema and is the union of what Claude Code, Codex, Gemini, OpenCode, Pi, and Multica all accept. Some harnesses support more fields (`allowed-tools`, `model`, etc.) — they're optional and ignored by others.

## Per-harness skill paths

| Harness | Skill directory | Slash-command directory | Plugin/Extension API |
|---------|-----------------|------------------------|----------------------|
| **Multica** (native) | (via `multica skill import`) | n/a | `multica skill import <repo>` |
| **Claude Code** | `~/.claude/skills/<name>/SKILL.md` | `~/.claude/commands/<name>.md` | `/plugin install <name>@<marketplace>` |
| **Codex** | `~/.codex/skills/<name>/SKILL.md` | `~/.codex/commands/<name>.md` | (clone to `~/.codex/plugins/`) |
| **Gemini** | `~/.gemini/skills/<name>/SKILL.md` | (in `GEMINI.md`) | `gemini extensions install <repo>` |
| **OpenCode** | `~/.config/opencode/skills/<name>/SKILL.md` | `~/.config/opencode/commands/<name>.md` | n/a |
| **Pi** | `~/.pi/skills/<name>/SKILL.md` | (in `AGENTS.md`) | n/a |
| **Cursor** | `.cursor/rules/<name>.mdc` (project-scoped) | n/a | (no skill concept; rules only) |
| **Copilot** | `.github/copilot-instructions.md` (project-scoped, concatenated) | n/a | (no skill concept) |
| **Droid** (factory.ai) | `droid plugin install <name>@<marketplace>` | n/a | plugin marketplace |

## What our adapters do

Each script in `adapters/` does the same thing in 4-10 lines of bash:

1. **Resolve `REPO_ROOT`** (the directory containing `skills/`).
2. **Make the target skill dir** (e.g. `~/.claude/skills/`).
3. **For each of our three skills** (`multica`, `multica-workflow`, `multica-onboarding`), create a symlink from the harness's expected path to `${REPO_ROOT}/skills/<name>/`.
4. (Codex/OpenCode also drop the `SKILL.md` into the `commands/` dir for slash-command discovery.)

Symlinks (not copies) mean `git pull` in the bundle propagates updates immediately to every harness — no re-install.

## Adding a new harness

1. Identify the harness's skill directory and frontmatter requirements.
2. Add `adapters/<harness>.sh` modeled after `adapters/claude-code.sh`.
3. Add an entry to `install.sh`'s `ALL_HARNESSES` array and a detection branch in the `detected()` function.
4. Add a row to the table above.

If the harness needs different frontmatter fields, the cleanest path is to keep `skills/*/SKILL.md` minimal (just `name` + `description`) and let the adapter generate a per-harness `SKILL.<harness>.md` if needed. We have not had to do this yet for any supported harness.

## Multica is special

Because Multica's own agent system runs the underlying tool (Claude Code, Codex, etc.) **inside Multica's daemon**, skills imported with `multica skill import` are available to every Multica-managed agent regardless of which harness binary is being driven. So if your primary workflow is Multica-managed, you only need `multica skill import` — the local harness adapters are for cases where you also run the harness directly (outside Multica) and want the same skills available there.

## Verification commands

```bash
# Multica
multica skill list | grep multica

# Claude Code
ls -la ~/.claude/skills/multica*/SKILL.md

# Codex
ls -la ~/.codex/skills/multica*/SKILL.md
ls -la ~/.codex/commands/multica*.md

# Gemini
ls -la ~/.gemini/skills/multica*/SKILL.md
gemini extensions list 2>/dev/null | grep multica

# OpenCode
ls -la ~/.config/opencode/skills/multica*/SKILL.md

# Pi
ls -la ~/.pi/skills/multica*/SKILL.md
```
