---
name: pr-auto-merge
description: Watch a sub-PR through bot review + CI, run /apply-pr-feedback on actionable feedback, then auto-merge into its base branch. Refuses to act when base is the trunk (main/master). Use after green-cycle opens a draft PR, or when the user types /auto-merge <pr-number>.
phase: 4-green
parallel: false
inputs: [pr-number]
outputs: [merged-pr | escalation-comment]
escalation: human-comment-on-pr
---

# /auto-merge <pr-number>

Autonomous watcher + merger for ATDD scenario sub-PRs. Replaces the per-scenario human checkpoint #2 inside `atdd-run`.

## When to use

- Right after `green-cycle` pushes a branch and opens a draft PR against the integration branch.
- Standalone via `/auto-merge <pr-number>` to take over an existing scenario PR.

**NEVER** invoke for the final PR that targets `main` / `master` / the project trunk. That PR is a hard human stop.

## Inputs

- `<pr-number>` — GitHub PR number.
- Optional flags:
  - `--idle-window <minutes>` — minutes with no bot activity before considering review complete (default `5`).
  - `--max-fix-iterations <n>` — cap on `/apply-pr-feedback` invocations (default `3`).
  - `--merge-method <squash|merge|rebase>` — default `squash`.
  - `--watch-timeout <minutes>` — hard wall-clock cap for the whole loop (default `60`).

## Preconditions

1. PR exists and is mergeable in principle (`gh pr view <pr> --json mergeable,baseRefName,state`).
2. `baseRefName` is NOT `main`, `master`, or the value of `.atdd-pipeline.json:trunk_branch`. If it is, ABORT with a clear message — humans gate the final merge.
3. PR is in `OPEN` state (not closed/merged).

If any precondition fails, print why and return without further action.

## Workflow

### 1. Mark ready for review

If PR is draft, mark it ready so bots (CodeRabbit, codex review, etc.) start reviewing:

```bash
gh pr ready <pr-number>
```

### 2. Watch CI

Wait until all required checks reach a terminal state — **without blocking the session** on Claude Code.

- **Claude Code (default):** run the watch in the background (`run_in_background`) or via the `Monitor` tool, so the session is free to advance other scenarios while CI runs. The harness re-invokes you when the watch exits.
  - With `Monitor`, the line filter MUST match **every** terminal state, not just success: `succeeded|passed|failed|failure|cancelled|timed_out|skipped|error`. A filter that greps only the success marker stays silent on a crash, so a failed run looks identical to "still running" — the classic Monitor footgun.
  - With background `Bash`, run an until-loop that exits when no check is still `IN_PROGRESS`/`QUEUED`.
- **Codex (fallback):** there is no `Monitor`/backgrounding, so block on `gh pr checks <pr-number> --watch --fail-fast=false`.

**Re-entrancy (both paths).** Background and `Monitor` tasks are NOT restored across a session restart. Never trust an in-memory timer or counter to know where CI stood; on every wake re-derive the truth from GitHub:

```bash
gh pr checks <pr-number> --json name,state,conclusion
```

Then branch on the derived state:

- **All checks `COMPLETED` and every conclusion green** → proceed to step 3.
- **Any `FAILURE`/`CANCELLED`/`TIMED_OUT`** → triage like `/apply-pr-feedback`: fetch the failing job logs (`gh run view <run-id> --log-failed`), attempt one targeted fix, push, restart step 2. This counts against `--max-fix-iterations`. Exceeded → escalate (step 6).

### 3. Bot idle watch

Track bot activity across three endpoints (treat `user.type == "Bot"` OR login matching `.atdd-pipeline.json:bot_logins` allowlist):

```bash
gh api "repos/{owner}/{repo}/issues/<pr>/comments"  --jq '.[]|{login:.user.login,t:.user.type,at:.updated_at}'
gh api "repos/{owner}/{repo}/pulls/<pr>/reviews"    --jq '.[]|{login:.user.login,t:.user.type,at:.submitted_at,state:.state}'
gh api "repos/{owner}/{repo}/pulls/<pr>/comments"   --jq '.[]|{login:.user.login,t:.user.type,at:.updated_at}'
```

The three endpoints are independent — fetch them concurrently (`&` + `wait`) and fold the timestamps into one `last_bot_activity = max(at)` across all bot entries.

Run the idle wait **without blocking the session** on Claude Code, same as step 2:

- **Claude Code (default):** background `Bash` until-loop (or `Monitor`) that re-polls and exits when `(now - last_bot_activity) >= idle_window`. The session stays free meanwhile; the harness re-invokes you on exit.
- **Codex (fallback):** block, sleeping `min(60s, remaining_idle_window)` between polls.

**Re-entrancy.** The idle window is derived state, never an in-memory clock: on every wake recompute `last_bot_activity` from the three endpoints and compare against `now`. A restart that loses the background task loses nothing — the next poll reconstructs the window from GitHub.

Exit conditions:

1. `(now - last_bot_activity) >= idle_window` → exit the idle watch, go to step 4.
2. Total elapsed in this step exceeds `watch_timeout` → escalate (step 6).

### 4. Classify outstanding feedback

After idle exit, compute:

- `has_changes_requested` — any review in state `CHANGES_REQUESTED` not later superseded by `APPROVED` from the same reviewer.
- `actionable_comments` — bot inline comments not marked resolved, and bot summary comments containing action verbs (e.g., CodeRabbit's "Actionable comments posted: N").

If `has_changes_requested == false` AND `actionable_comments == 0` AND CI is green → step 5 (merge).
Otherwise → step 4a.

#### 4a. Invoke /apply-pr-feedback

Increment the fix iteration counter. If it exceeds `--max-fix-iterations` → escalate (step 6).

Invoke the bundled [`apply-pr-feedback`](../apply-pr-feedback/SKILL.md) skill against this PR. It returns `{pushed_commit, actionable_remaining, all_out_of_scope, replies_posted}` (see its **Return contract**). Branch on `actionable_remaining`, NOT on "did it push":

- `actionable_remaining == 0` AND `pushed_commit == true` → fixes landed; return to step 2 (CI watch).
- `actionable_remaining == 0` AND `pushed_commit == false` (everything was out of scope, replies posted) → nothing left to fix; re-run step 4 classification, then step 5 (merge). Do NOT loop.
- `actionable_remaining > 0` AND `pushed_commit == true` → partial progress; return to step 2.
- `actionable_remaining > 0` AND `pushed_commit == false` → the skill could not make progress (error or stuck). Do NOT re-invoke it on the same unchanged feedback; escalate (step 6).

### 5. Merge

```bash
gh pr merge <pr-number> --<merge-method> --delete-branch
```

Verify `gh pr view <pr> --json state,mergeCommit` reports `MERGED`. Return success.

### 6. Escalation

Post a comment on the PR:

```
ESCALATED: pr-auto-merge gave up after <reason>.
- CI status: <pass|fail|timeout>
- Bot reviewers seen: <list>
- Fix iterations consumed: <n>/<max>
- Last bot activity: <iso8601>

Hand off to a human.
```

Do NOT merge. Leave the PR open. Return.

## Configuration knobs (read from `.atdd-pipeline.json`)

```json
{
  "auto_merge": {
    "enabled": true,
    "idle_window_minutes": 5,
    "max_fix_iterations": 3,
    "watch_timeout_minutes": 60,
    "merge_method": "squash",
    "bot_logins": ["coderabbitai", "coderabbitai[bot]", "github-actions[bot]", "codex", "codex-bot"]
  },
  "trunk_branch": "main"
}
```

CLI flags override file values; file values override built-in defaults.

## Anti-patterns

- Do NOT merge a PR whose `baseRefName` matches `trunk_branch`. This guard is non-negotiable.
- Do NOT squash a CHANGES_REQUESTED review by force-merging. The classification step is the gate.
- Do NOT run `/apply-pr-feedback` on a PR that has no actionable comments — wastes iterations.
- Do NOT silence failing CI by disabling required checks. Fix the underlying cause or escalate.
- Do NOT keep polling past `watch_timeout`. Escalate so a human can investigate stuck bots.

## Composition

- [`apply-pr-feedback`](../apply-pr-feedback/SKILL.md) (bundled with this plugin) handles the comment-application loop. This skill orchestrates it and branches on the `{pushed_commit, actionable_remaining, all_out_of_scope, replies_posted}` return contract — "pushed no commit" alone never decides the loop; `actionable_remaining` does. Zero external dependency.
- `green-cycle` opens the PR; this skill takes over from there when `auto_merge.enabled == true`.
- `atdd-run` chains `green-cycle` → `pr-auto-merge` per scenario, then opens the final integration→trunk PR and stops.

## Outputs

- Merged PR (success).
- `specs/<us-slug>/.cycles/<issue-number>/auto-merge.log` — timeline of CI watches, bot polls, fix iterations.
- Escalation comment on the PR (failure).
