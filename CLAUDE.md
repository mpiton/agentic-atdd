# Plugin layout

Skills live under `skills/<bucket>/<name>/SKILL.md` with optional supporting `.md` files in the same folder.

Buckets:

- `spec/` — input + scenario generation + scenario review
- `sync/` — issue tracker sync
- `execute/` — RED/GREEN cycle + reviewers + auto-merge
- `orchestrate/` — end-to-end drivers + per-repo setup

Every skill in any bucket MUST:

1. Have a `SKILL.md` with the required frontmatter (`name`, `description`, `phase`, plus skill-specific fields).
2. Be listed in the top-level `README.md`.
3. Be registered in `.claude-plugin/plugin.json`.

## Non-skill components

The plugin also ships components that are not skills. They live at the plugin root (not under `skills/`, not inside `.claude-plugin/`):

- `hooks/` — deterministic guardrails. `hooks/hooks.json` is auto-discovered by Claude Code when the plugin is installed via `/plugin`; it wires `PreToolUse`/etc. events to scripts in the same folder. Today: `guard-merge.sh`, which blocks any merge/push into the trunk branch (hardening the prose rule in `pr-auto-merge`). Hooks are Claude-Code-only — every guardrail they enforce must also exist as a prose rule in the relevant SKILL.md so Codex stays protected. The manual `install.sh` path now registers this hook into `~/.claude/settings.json` (idempotent, backed up, and skipped on Codex); `hooks/README.md` documents the exact block and the no-`jq` fallback.
- `agents/` — plugin subagent definitions (markdown + frontmatter), auto-discovered under `/plugin`. Today: `atdd-scenario` (runs RED+GREEN for one scenario in an isolated worktree) and `atdd-merge` (serialized merge of one sub-PR), both dispatched by the Stage 3 workflow via `agentType`. Keep them **thin** — they point at the SKILL.md files for logic, they do not restate it (avoids drift, principle #1). Plugin agents ignore `hooks`/`mcpServers`/`permissionMode` frontmatter by design. `isolation` is optional and set only when an agent must run in its own checkout: `atdd-scenario` sets `isolation: worktree` for parallel produce; `atdd-merge` deliberately omits it because it must operate on the real working tree (it rebases onto the live integration tip). When `isolation` IS set, `worktree` is the only valid value — that constraint is about the value, not a requirement that every agent be isolated. Agents are Claude-Code-only; Codex uses the sequential path, so the SKILL.md files stay the canonical source.
- `workflows/` — dynamic-workflow scripts (`.workflow.mjs`) the model launches via the Workflow tool. Today: `atdd-stage3.workflow.mjs`, the opt-in parallel Stage 3 (produce in worktrees, serialized merge). It is experimental and gated: `atdd-run` only launches it when `stage3_mode == "workflow"` and the Workflow tool is available, else it runs the sequential loop. Workflow scripts are plain JS (not TS), have no `Date.now`/`Math.random`, and put a pure-literal `meta` block first. Validate syntax by wrapping the body in an async function and running `node --check` (top-level `return`/`await` are legal in the workflow runtime but not in a bare module).
- `tests/contracts/` — cross-skill string-contract checks (`check-contracts.sh`). When a producer→consumer handoff rides on an exact string (a `VERDICT:` line, an `ESCALATED:` phrase, the apply-pr-feedback return keys), add an assertion here in the same change.

Durable run artifacts (written at runtime, not shipped): `specs/<us-slug>/run-state.json` is the orchestrator's per-scenario crash-resume index. GitHub Issues stays the system of record; run-state is a local fast index reconciled against GitHub on resume.

## SKILL.md frontmatter contract

```yaml
---
name: <kebab-case-name>           # matches folder
description: <one-line summary>   # surfaced to the model for skill discovery
phase: <1-input|2-spec|3-sync|4-red|4-green|orchestrate|review>
parallel: <true|false>            # only meaningful when the skill dispatches sub-skills
inputs: [<input-name>, ...]
outputs: [<output-name>, ...]
escalation: <none|human-comment-on-issue|human-comment-on-pr|human-checkpoint>
---
```

## Installer

`scripts/install.sh` is the single entry point. It walks `skills/<bucket>/<name>/SKILL.md` and symlinks each skill folder into both `~/.claude/skills/<name>` and `~/.codex/skills/<name>` (when `~/.codex/` is present). It also writes a thin slash-command stub per command listed in `.claude-plugin/plugin.json:commands` into `~/.claude/commands/`. On the Claude side it additionally symlinks `agents/*.md` into `~/.claude/agents/` and registers the trunk-merge hook in `~/.claude/settings.json` (idempotent, backed up). Codex skips agents and the hook (Claude-only); Stage 3 `workflow` mode needs `${CLAUDE_PLUGIN_ROOT}`, which only the `/plugin install` flow sets, so a manual install stays in sequential mode.

`scripts/sync-codex.sh` is a deprecated alias that delegates to `install.sh`. Both Claude Code and Codex consume the same `SKILL.md` format, so there is no longer a translation step.

## Versioning

SemVer. Track changes in `CHANGELOG.md`. Pre-1.0, anything can break between minors.
