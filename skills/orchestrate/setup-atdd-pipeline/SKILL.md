---
name: setup-atdd-pipeline
description: First-run configuration for the atdd-pipeline plugin in the current project. Picks an issue tracker, spec base path, commit style, and writes .atdd-pipeline.json at the repo root. Idempotent. Use after installing the plugin in a new repo.
phase: orchestrate
parallel: false
inputs: []
outputs: [atdd-pipeline-json]
escalation: none
---

# /setup-atdd-pipeline

One-time per-repo configuration. Produces `.atdd-pipeline.json` at the repo root, which every other skill reads at the top of its workflow.

## When to use

- First time the plugin runs in a repo.
- After moving the repo to a different tracker.
- Whenever `.atdd-pipeline.json` is missing.

## Interview

Ask, in order. If the answer is unclear, push back; do NOT guess.

1. **Tracker.** Where do scenario sub-issues live?
   - `github` — `gh` CLI, parent / US / scenario hierarchy.
   - `local` — markdown files under `.atdd/issues/` (no remote tracker, for offline / personal use).
2. **Repo for GitHub** (only if tracker=github). Default: current `gh repo view` target.
3. **Spec base path.** Where to write `context.md` and `.feature` files. Default: `specs/`.
4. **Test path conventions.** One path per test level, used by `red-cycle` to place new tests:
   - `use-case` (default: `tests/use-case/`)
   - `e2e` (default: `tests/e2e/`)
   - `ui` (default: `tests/ui/`)
5. **Commit style.** `conventional` (default) or `freeform`.
6. **Reviewer execution.** `parallel` (default; uses `Task` tool on Claude Code) or `sequential` (Codex default, or low-budget mode).
7. **Shared-language file.** Default: `CONTEXT.md` at repo root. If absent, propose creating one and offer `grill-with-docs` from mattpocock skills as the way to populate it.
8. **ADR directory.** Default: `docs/adr/`. Reviewers consult these.
9. **Trunk branch.** Default: `main`. The final PR targets this; sub-PRs MUST NOT target it.
10. **Integration branch pattern.** Default: `atdd/<us-slug>/integration`. Sub-PRs (one per scenario) target this branch; once all are merged, the orchestrator opens a single PR from this branch to `trunk_branch` and stops.
11. **Auto-merge of sub-PRs.** Default: `enabled`. Knobs:
    - `idle_window_minutes` (default `5`) — bot inactivity before considering review complete.
    - `max_fix_iterations` (default `3`) — cap on `/fix-pr-comments` cycles per sub-PR.
    - `watch_timeout_minutes` (default `60`) — wall-clock cap per sub-PR.
    - `merge_method` (default `squash`).
    - `bot_logins` — extra login allowlist beyond GitHub's `user.type == "Bot"` (defaults include `coderabbitai`, `coderabbitai[bot]`, `github-actions[bot]`, `codex`, `codex-bot`).

## Output

Write `.atdd-pipeline.json` at the repo root:

```json
{
  "version": 1,
  "tracker": {
    "kind": "github",
    "repo": "owner/name"
  },
  "paths": {
    "specs": "specs/",
    "tests": {
      "use-case": "tests/use-case/",
      "e2e": "tests/e2e/",
      "ui": "tests/ui/"
    },
    "context": "CONTEXT.md",
    "adr": "docs/adr/"
  },
  "commits": "conventional",
  "reviewers": {
    "mode": "parallel"
  },
  "trunk_branch": "main",
  "integration_branch_pattern": "atdd/{us_slug}/integration",
  "auto_merge": {
    "enabled": true,
    "idle_window_minutes": 5,
    "max_fix_iterations": 3,
    "watch_timeout_minutes": 60,
    "merge_method": "squash",
    "bot_logins": [
      "coderabbitai",
      "coderabbitai[bot]",
      "github-actions[bot]",
      "codex",
      "codex-bot"
    ]
  }
}
```

## Idempotency

If `.atdd-pipeline.json` already exists, read it, present the current values, ask only for fields the user wants to change. Never silently overwrite.

## Sanity checks (post-write)

- `gh auth status` (when tracker=github). Warn if not authenticated.
- Each `paths.tests.*` directory exists or its parent exists. If neither, ask before creating.
- `paths.context` exists. If not, suggest invoking `grill-with-docs` to bootstrap it.
- `trunk_branch` exists locally and on the remote (`git rev-parse --verify origin/<trunk>`). Warn otherwise.
- `auto_merge.enabled == true` AND `gh pr merge --help` supports the chosen `merge_method` flag.

## Handoff

After completion, suggest the next step: `/atdd-run <us-slug>` to drive the full pipeline, or `/impact-map` to capture a new story.
