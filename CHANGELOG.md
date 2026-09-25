# Changelog

All notable changes to this plugin land here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `from-linear` skill (`/from-linear <ticket-id>`) — third entry point next to `impact-map` and `from-issue`. Imports a Linear card by identifier (e.g. `ENG-123`): resolves an access path at runtime (Linear MCP tools → `linear` CLI on PATH → GraphQL API with `LINEAR_API_KEY`), parses the description and comments into `specs/<us-slug>/context.md`, interviews for the missing actor/action/data/test-level fields, and leaves one back-link comment on the card. GitHub Issues stays the pipeline database: unlike `from-issue` it does not seed `issues.json`, so `to-issues-atdd` creates the parent and US fresh.

## [0.2.0] — 2026-06-02

### Added

- `scripts/install.sh` now also symlinks `agents/` into `~/.claude/agents/` and registers the trunk-merge `PreToolUse` hook in `~/.claude/settings.json` (idempotent, backed up first), so a manual / symlink install gets the Claude-only machinery that `/plugin install` auto-discovers. Codex installs skip both — it has no subagent or hook system.
- `apply-pr-feedback` skill bundled inside the plugin. Replaces the external `fix-pr-comments` dependency that `pr-auto-merge` used to call. Zero external skill dep now.
- `.claude-plugin/marketplace.json` at the repo root, turning the repo into a single-plugin Claude Code marketplace. Install via `/plugin marketplace add mpiton/agentic-atdd` then `/plugin install atdd-pipeline@agentic-atdd`.
- `plugin.json` enriched with `homepage`, `repository`, `license`, `keywords`, `category`, structured `author`. Marketplace-schema compliant.
- `hooks/` with `guard-merge.sh` + `hooks/hooks.json` — a `PreToolUse` hook that blocks any merge or push into the trunk branch: `gh pr merge` whose base resolves to trunk (base read via `gh pr view`, fail-closed if unresolvable), `gh api .../merges`, and `git push <src>:<trunk>`. Scoped to repos carrying `.atdd-pipeline.json`, so it's a no-op in unrelated repos. Turns design principle #4 from a prose instruction into a rule the harness enforces on the Claude Code path. Auto-discovered under `/plugin install`; under the manual `install.sh` path it must be wired into `settings.json` by hand (see `hooks/README.md`).
- `tests/contracts/check-contracts.sh` — 50 cross-skill string-contract checks. `tests/fixtures/` catches one reviewer prompt drifting from its golden; this catches two skills falling out of agreement (a producer renaming a `VERDICT:`/`ESCALATED:` string or a return key a consumer still greps for). Pure grep, runs in any CI.
- `specs/<us-slug>/run-state.json` — the orchestrator's per-scenario crash-resume index, written after every phase transition and reconciled against GitHub on resume. GitHub Issues stays the system of record; this is the local fast index. Defined in `atdd-run` under *Run state*.
- `workflows/atdd-stage3.workflow.mjs` — an **opt-in, experimental** dynamic-workflow for Stage 3 that produces every scenario's RED+GREEN in parallel isolated worktrees and serializes only the merge (rebase onto the live integration tip + CI re-run + `pr-auto-merge`). Reviewer/phase results come back schema-validated, not prose-parsed. Launched by `atdd-run` via the Workflow tool only when `stage3_mode == "workflow"` and the Workflow tool is available; otherwise the sequential loop runs unchanged. Syntax-validated; not yet exercised end-to-end against a live repo, so it ships behind the flag, default off.
- `agents/atdd-scenario.md` and `agents/atdd-merge.md` — thin plugin subagent definitions the Stage 3 workflow dispatches via `agentType` (scenario produce in a worktree; serialized merge). Auto-discovered under `/plugin`; they point at the SKILL.md files rather than restating them.

### Changed

- `pr-auto-merge`, `green-cycle`, `atdd-run`, `setup-atdd-pipeline`, `docs/USAGE.md`, `docs/workflows.html` and `README.md` now reference `apply-pr-feedback` instead of `fix-pr-comments`.
- README install section now leads with the `/plugin` flow; the `install.sh` symlink flow is documented as the Codex-CLI / manual fallback.
- `red-cycle`: the "fails for the right reason" setup loop is now bounded (3 attempts, then escalate) instead of looping unbounded — closes a gap against principle #3 (bounded auto-correction).
- `apply-pr-feedback`: documents an explicit return contract `{pushed_commit, actionable_remaining, all_out_of_scope, replies_posted}`. `pr-auto-merge` now branches on `actionable_remaining`, removing the "pushed no commit means done" ambiguity that conflated three distinct outcomes (fixed-and-pushed, all-out-of-scope, stuck).
- `atdd-run` Stage 4 classifies every scenario `merged | escalated | unmerged`, refuses to open the final PR while any scenario is `unmerged`, and opens that PR as a draft with a leading "incomplete" section when scenarios escalated — an escalated (skipped) scenario can no longer slip silently into the integration→trunk PR. Resume semantics gain a fine-grained per-scenario path on top of `--from-stage`.
- Reviewer dispatch references updated from the `Task` tool to its current name `Agent` (the `Task` alias still works) across `green-cycle`, `atdd-run`, `setup-atdd-pipeline`, `README.md`, and `docs/USAGE.md`.
- Plugin layout contract (`CLAUDE.md`) now documents the `hooks/`, `agents/`, `workflows/`, and `tests/contracts/` components and the runtime `run-state.json` artifact.
- `pr-auto-merge`: the CI watch and bot-idle watch are non-blocking on Claude Code — background `Bash` / `Monitor` instead of a session-blocking `gh pr checks --watch` and `sleep` loop, so the session can advance other scenarios while CI runs. Re-entrant: state is re-derived from `gh` on every wake (background/Monitor tasks aren't restored across a session restart), and the Monitor filter must match every terminal state, not just success. The blocking `--watch` + sleep-poll stays the Codex fallback.
- `atdd-run`: escalation is now a first-class contract owned by the orchestrator — a structured entry in `escalations.md`, a `status: "escalated"` mark in `run-state.json`, and a best-effort `PushNotification` (no-op under Codex) so a single blocked scenario in a parallel run isn't lost in a comment thread. Stage 4 already refuses to ready the final PR while work is incomplete and surfaces escalations in the blocking header.
- `spec-generate`: reads `context.md` as answered ground and asks only genuinely-new ambiguities, instead of re-eliciting the actor / action / rules that `impact-map` (or `from-issue`) already captured — the main avoidable token cost in the spec phase. Pure prose, so it holds under Codex too.
- `atdd-stage3.workflow.mjs`: accepts an optional `conventions` cache (shared language + relevant ADRs, extracted once) handed to each scenario agent so N parallel agents don't each re-discover the same conventions; logs Stage 3 token spend via `budget`.

## [0.1.0] — 2026-05-18

First public release.

### Added

- Twelve composable skills covering the full ATDD pipeline:
  - Spec: `impact-map`, `from-issue`, `spec-generate`, `spec-review`.
  - Sync: `to-issues-atdd`.
  - Execute: `red-cycle`, `green-cycle`, `review-fidelity`, `review-architecture`, `review-intent`, `pr-auto-merge`.
  - Orchestrate: `atdd-run`, `setup-atdd-pipeline`.
- Slash command set covering every skill plus the end-to-end `/atdd-run`.
- `pr-auto-merge` skill that watches sub-PRs through CI and bot review, runs `apply-pr-feedback` on actionable feedback up to a bounded number of iterations, then squash-merges into the integration branch. Refuses to operate on PRs whose base is the trunk.
- Mandatory integration branch (`atdd/<slug>/integration`) for sub-PRs, provisioned by `to-issues-atdd`. The final PR `integration → main` is the second and only human gate after the spec review.
- Single-source-of-truth installer (`scripts/install.sh`) that symlinks every skill folder into both `~/.claude/skills/` and `~/.codex/skills/`. `scripts/sync-codex.sh` kept as a deprecated alias.
- Worked example under `examples/cart-checkout/` with a full artifact set (context, two `.feature` files, a `review.md` carrying a `REGENERATE` verdict, the resulting `issues.json`).
- Reviewer fixtures under `tests/fixtures/` (pass/fail goldens for each of the three reviewer skills) to catch prompt regressions.
- Side-by-side workflow diagram (`docs/workflows.html`) covering three entry paths: existing GitHub issue, fresh feature with PRD in hand, greenfield.
- `docs/USAGE.md` covering the same three paths in prose, plus resume semantics and troubleshooting.
- MIT license.

### Notes

The plugin is still pre-1.0. Skill names, frontmatter, and on-disk artifact paths can still change. Once the API settles, the next release will be 1.0.0 and breaking changes will follow SemVer.
