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

- `hooks/` — deterministic guardrails. `hooks/hooks.json` is auto-discovered by Claude Code when the plugin is installed via `/plugin`; it wires `PreToolUse`/etc. events to scripts in the same folder. Today: `guard-merge.sh`, which blocks any merge/push into the trunk branch (hardening the prose rule in `pr-auto-merge`). Hooks are Claude-Code-only — every guardrail they enforce must also exist as a prose rule in the relevant SKILL.md so Codex stays protected. The manual `install.sh` path does NOT register hooks; that is documented in `hooks/README.md`.
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

`scripts/install.sh` is the single entry point. It walks `skills/<bucket>/<name>/SKILL.md` and symlinks each skill folder into both `~/.claude/skills/<name>` and `~/.codex/skills/<name>` (when `~/.codex/` is present). It also writes a thin slash-command stub per command listed in `.claude-plugin/plugin.json:commands` into `~/.claude/commands/`.

`scripts/sync-codex.sh` is a deprecated alias that delegates to `install.sh`. Both Claude Code and Codex consume the same `SKILL.md` format, so there is no longer a translation step.

## Versioning

SemVer. Track changes in `CHANGELOG.md`. Pre-1.0, anything can break between minors.
