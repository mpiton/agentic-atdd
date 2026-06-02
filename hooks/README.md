# hooks/

Deterministic guardrails that run outside the model. Today there is one: `guard-merge.sh`.

## guard-merge.sh — trunk-merge guard

A `PreToolUse` hook (matcher `Bash`) that blocks any command which would merge or push into the trunk branch. It turns design principle #4 — *scenario sub-PRs target the integration branch, never trunk* — from a prose instruction the model is asked to honour into a rule the harness enforces.

What it blocks, when the current repo has a `.atdd-pipeline.json`:

- `gh pr merge ...` whose PR base resolves to the trunk (`trunk_branch` from `.atdd-pipeline.json`, plus `main` / `master`). The base is resolved with `gh pr view --json baseRefName`. If it can't be resolved, the merge is **blocked** (fail-closed) — a wrong block just means you merge by hand.
- `gh api .../merges` — the direct merge API, which would bypass `gh pr merge` entirely.
- `git push ... <src>:<trunk>` — pushing some other ref onto trunk. A plain `git push origin main` that fast-forwards trunk onto itself is left alone.

What it does **not** touch:

- Any repo without a `.atdd-pipeline.json`. The hook is global (it loads for every repo once the plugin is installed), so it scopes itself to pipeline-managed repos and is a no-op everywhere else.
- The human merging the final `integration → trunk` PR. That is a human gate (#2): you merge it in the GitHub UI or your own terminal, neither of which is a Claude tool call, so the hook never sees it. It only fires on commands the agent runs.

### Requirements

`jq` must be on `PATH` — the hook parses the tool-call payload with it. If `jq` is missing the guard goes **inert** (exits 0) rather than blocking, so a missing dependency degrades to today's prose-only enforcement instead of wedging every `Bash` call. Manual installers on a machine without `jq` should install it (`apt install jq` / `brew install jq`) or the guard simply won't fire.

### Wiring

Installed via `/plugin install` (recommended): `hooks/hooks.json` at the plugin root is auto-discovered. Nothing else to do.

Manual / symlink install (`scripts/install.sh`): that script only symlinks skill folders, so it does **not** register this hook. On **Claude Code**, enable it by adding this block to your `~/.claude/settings.json`, with `command` pointing at the absolute path of `guard-merge.sh` in your checkout:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "/absolute/path/to/atdd-pipeline/hooks/guard-merge.sh" }
        ]
      }
    ]
  }
}
```

Under **Codex** there is no hook system, so the guard can't run there at all regardless of wiring — the prose rule in `pr-auto-merge` is the enforcement (see Portability).

### Portability

Hooks are a Claude Code feature. Under Codex there is no `PreToolUse`, so the guard does not run — the prose refusal in `pr-auto-merge` and `green-cycle` remains the enforcement there. Treat this hook as defense-in-depth on the Claude path, not a replacement for the prose rule.
