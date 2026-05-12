# ARCHITECTURE.md

Why this bundle looks the way it does.

## Three skills, not one

We split the bundle into three discrete skills (`multica`, `multica-workflow`, `multica-onboarding`) instead of shipping one mega-skill. Three reasons:

1. **Skills auto-activate on description match.** A user typing "how do I create a multica issue" should trigger only the CLI-reference skill — not a 2000-line workflow primer. A user typing "set up my multica pipeline" should trigger only the workflow skill.
2. **Different update cadence.** Multica's CLI surface changes when the platform ships a release. The workflow design changes when *we* learn something. The onboarding defaults change when the upstream ecosystem moves. Decoupling lets each evolve.
3. **Different audiences.** A solo dev wiring Multica for the first time wants `multica`. A team adopting a structured pipeline wants `multica-workflow`. A platform engineer rolling this out to N projects wants `multica-onboarding`.

## "Macro state + label" instead of forking Multica

Symphony defines its own 11-state schema. We could have argued for Multica to expose custom states. Instead we chose to **work with Multica's fixed 7** and use orthogonal labels for the sub-phase axis.

Trade-offs:

- ✅ Zero changes to Multica required — the bundle works on any Multica instance today.
- ✅ Multica's native UI/reporting still works (`in_progress` means "engineers working", `in_review` means "post-implementation").
- ❌ Labels are weaker typing than states — a typo (`phase:wokr`) won't get caught at the boundary.

The `multica-flow` CLI mitigates the typo risk by being the canonical label-mutator; agents are instructed to use the structured `multica issue label` commands rather than free-form text. We can revisit if Multica adds custom states later.

## The agent writes its own next-state

Borrowed directly from Symphony's `tracker.py` design: the orchestrator is read-only; the workers write. This means:

- No central state machine to keep in sync with reality.
- Failures degrade gracefully — if an agent crashes mid-turn, the ticket stays in its current phase and gets retried by the daemon.
- Adding a new phase is a 3-step change: new `lanes/0X-newphase.md`, new agent slug, update the `next()` mapping in `multica-flow`.

## Why `bin/` is bash, not Python/Node

`multica-flow` and `multica-skill` are thin shells around the `multica` CLI. Keeping them bash means:

- No runtime to install.
- Trivial to read and modify (~150 lines each).
- Same UX inside any harness that can shell out.

If the CLI grows beyond what bash can comfortably express, we'll port to whatever the user already has installed (Node if Playwright is around, Python if they're a data-science shop). Until then, bash wins.

## Fresh context per phase

Symphony's most important insight: **don't try to fix a review finding in the same conversation that produced the original code.** The agent's context is polluted by everything it just did; it'll defend its prior decisions rather than fix them.

multica-skill enforces this by reassigning to a *different agent slug* on every phase. Each slug has its own system prompt, model selection, and `--max-turns` budget. Even when the underlying tool is the same (`claude-code` everywhere), the agent spawns a fresh session — fresh context, fresh perspective.

Open question: should we use a *different* tool per phase (Claude for explore, Codex for work, Gemini for review)? The workflow supports it (`templates/workflow.yaml` lets you set per-phase agent slugs to anything). We don't recommend it by default because the prompt vocabulary across the lane files is shared; mixed tools means more variance to manage. Try it on a side project before adopting org-wide.

## Onboarding registers three packs

We register `obra/superpowers`, `leweii/atlassian-cli`, and Playwright. Why these three:

- **superpowers**: it *is* the methodology vocabulary every other skill plugs into (brainstorming → planning → TDD → verification). Almost every other skill in the wider ecosystem assumes it's available.
- **atlassian-cli**: most ticket systems in the wild are still Jira. Even if the team uses Multica for AI dispatch, the source of truth may live in Jira. The skill wraps `acli` so an agent can read/transition Jira tickets from inside its session.
- **Playwright**: only realistic way to produce machine-checkable QA evidence for a web UI. The QA phase prompt explicitly assumes it's available.

We deliberately don't register other defaults (testing libraries, linters, IDE extensions) — those should be per-project decisions, not per-machine.

## What this is not

- **Not a Multica fork or wrapper.** The bundle adds zero abstraction over `multica`. You can drop into raw `multica issue ...` at any time and the pipeline still works.
- **Not a substitute for code review.** The Review phase agent is fast feedback, not final approval. PR-time human review still applies.
- **Not deterministic.** Agents are LLMs. Two runs of the same ticket may produce different (both valid) implementations. The pipeline structure constrains *what* they produce, not *how* they produce it.
