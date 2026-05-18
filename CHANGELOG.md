# Changelog

All notable changes to this plugin land here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-18

First public release.

### Added

- Twelve composable skills covering the full ATDD pipeline:
  - Spec: `impact-map`, `from-issue`, `spec-generate`, `spec-review`.
  - Sync: `to-issues-atdd`.
  - Execute: `red-cycle`, `green-cycle`, `review-fidelity`, `review-architecture`, `review-intent`, `pr-auto-merge`.
  - Orchestrate: `atdd-run`, `setup-atdd-pipeline`.
- Slash command set covering every skill plus the end-to-end `/atdd-run`.
- `pr-auto-merge` skill that watches sub-PRs through CI and bot review, runs `fix-pr-comments` on actionable feedback up to a bounded number of iterations, then squash-merges into the integration branch. Refuses to operate on PRs whose base is the trunk.
- Mandatory integration branch (`atdd/<slug>/integration`) for sub-PRs, provisioned by `to-issues-atdd`. The final PR `integration → main` is the second and only human gate after the spec review.
- Single-source-of-truth installer (`scripts/install.sh`) that symlinks every skill folder into both `~/.claude/skills/` and `~/.codex/skills/`. `scripts/sync-codex.sh` kept as a deprecated alias.
- Worked example under `examples/cart-checkout/` with a full artifact set (context, two `.feature` files, a `review.md` carrying a `REGENERATE` verdict, the resulting `issues.json`).
- Reviewer fixtures under `tests/fixtures/` (pass/fail goldens for each of the three reviewer skills) to catch prompt regressions.
- Side-by-side workflow diagram (`docs/workflows.html`) covering three entry paths: existing GitHub issue, fresh feature with PRD in hand, greenfield.
- `docs/USAGE.md` covering the same three paths in prose, plus resume semantics and troubleshooting.
- MIT license.

### Notes

The plugin is still pre-1.0. Skill names, frontmatter, and on-disk artifact paths can still change. Once the API settles, the next release will be 1.0.0 and breaking changes will follow SemVer.
