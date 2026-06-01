# Changelog

All notable changes to this plugin land here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `apply-pr-feedback` skill bundled inside the plugin. Replaces the external `fix-pr-comments` dependency that `pr-auto-merge` used to call. Zero external skill dep now.
- `.claude-plugin/marketplace.json` at the repo root, turning the repo into a single-plugin Claude Code marketplace. Install via `/plugin marketplace add mpiton/agentic-atdd` then `/plugin install atdd-pipeline@agentic-atdd`.
- `plugin.json` enriched with `homepage`, `repository`, `license`, `keywords`, `category`, structured `author`. Marketplace-schema compliant.
- `hooks/` with `guard-merge.sh` + `hooks/hooks.json` — a `PreToolUse` hook that blocks any merge or push into the trunk branch: `gh pr merge` whose base resolves to trunk (base read via `gh pr view`, fail-closed if unresolvable), `gh api .../merges`, and `git push <src>:<trunk>`. Scoped to repos carrying `.atdd-pipeline.json`, so it's a no-op in unrelated repos. Turns design principle #4 from a prose instruction into a rule the harness enforces on the Claude Code path. Auto-discovered under `/plugin install`; under the manual `install.sh` path it must be wired into `settings.json` by hand (see `hooks/README.md`).
- `tests/contracts/check-contracts.sh` — 32 cross-skill string-contract checks. `tests/fixtures/` catches one reviewer prompt drifting from its golden; this catches two skills falling out of agreement (a producer renaming a `VERDICT:`/`ESCALATED:` string or a return key a consumer still greps for). Pure grep, runs in any CI.
- `specs/<us-slug>/run-state.json` — the orchestrator's per-scenario crash-resume index, written after every phase transition and reconciled against GitHub on resume. GitHub Issues stays the system of record; this is the local fast index. Defined in `atdd-run` under *Run state*.

### Changed

- `pr-auto-merge`, `green-cycle`, `atdd-run`, `setup-atdd-pipeline`, `docs/USAGE.md`, `docs/workflows.html` and `README.md` now reference `apply-pr-feedback` instead of `fix-pr-comments`.
- README install section now leads with the `/plugin` flow; the `install.sh` symlink flow is documented as the Codex-CLI / manual fallback.
- `red-cycle`: the "fails for the right reason" setup loop is now bounded (3 attempts, then escalate) instead of looping unbounded — closes a gap against principle #3 (bounded auto-correction).
- `apply-pr-feedback`: documents an explicit return contract `{pushed_commit, actionable_remaining, all_out_of_scope, replies_posted}`. `pr-auto-merge` now branches on `actionable_remaining`, removing the "pushed no commit means done" ambiguity that conflated three distinct outcomes (fixed-and-pushed, all-out-of-scope, stuck).
- `atdd-run` Stage 4 classifies every scenario `merged | escalated | unmerged`, refuses to open the final PR while any scenario is `unmerged`, and opens that PR as a draft with a leading "incomplete" section when scenarios escalated — an escalated (skipped) scenario can no longer slip silently into the integration→trunk PR. Resume semantics gain a fine-grained per-scenario path on top of `--from-stage`.
- Reviewer dispatch references updated from the `Task` tool to its current name `Agent` (the `Task` alias still works) across `green-cycle`, `atdd-run`, `setup-atdd-pipeline`, `README.md`, and `docs/USAGE.md`.
- Plugin layout contract (`CLAUDE.md`) now documents the `hooks/` and `tests/contracts/` components and the runtime `run-state.json` artifact.

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
