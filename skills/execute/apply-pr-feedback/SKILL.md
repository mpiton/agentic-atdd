---
name: apply-pr-feedback
description: Fetch bot and human review comments on the current PR, apply every actionable change in scope, commit and push. Used by pr-auto-merge inside the ATDD pipeline. Can also be invoked standalone via /apply-pr-feedback or /apply-pr-feedback <pr-number>.
phase: 4-green
parallel: false
inputs: [pr-number?]
outputs: [committed-fixes, pushed-branch]
escalation: human-comment-on-pr
allowed-tools: Bash(gh :*), Bash(git :*), Read, Edit, MultiEdit
---

# /apply-pr-feedback

Apply every actionable review comment on a PR. Scoped to the comments that exist when the skill runs; nothing else. Used as a step inside `pr-auto-merge` and standalone for any PR you want to clear by hand.

## When to use

- The pipeline calls this from `pr-auto-merge` after the bot idle window closes and at least one actionable comment is still open.
- You want to clear bot review feedback on a PR without running the full pipeline.

## Inputs

- `<pr-number>` (optional). If omitted, the skill resolves the current branch's PR via `gh pr status`.

## Context the skill collects before doing anything

```bash
gh pr view <pr> --json number,headRefName,baseRefName,state,mergeable
git branch --show-current
git status --short
git log --oneline -3
```

If the PR is not open or the working tree is dirty, abort.

## Workflow

### 1. Fetch comments

```bash
# Review-level (bot summaries, CHANGES_REQUESTED, approvals)
gh api repos/{owner}/{repo}/pulls/<pr>/reviews   --jq '.[]|{id,user:.user.login,state,body,submitted_at}'

# Inline code comments (the ones tied to file:line)
gh api repos/{owner}/{repo}/pulls/<pr>/comments  --jq '.[]|{id,user:.user.login,path,line,body,in_reply_to_id}'

# Issue-style PR comments (CodeRabbit summaries land here)
gh api repos/{owner}/{repo}/issues/<pr>/comments --jq '.[]|{id,user:.user.login,body,updated_at}'
```

Capture all three. Filter out comments already resolved or already replied to with a fix commit reference.

### 2. Classify

For each comment, decide one of:

- **Actionable** — concrete code change at a specific file:line.
- **Question** — needs a reply, not a code change.
- **Out of scope** — refactor / opinion / unrelated to this PR's diff. Do NOT touch.
- **Already addressed** — earlier commit fixed it; mark resolved.

Build a checklist:

```
[ ] reviewers/coderabbitai · src/cart/checkout.ts:42 · "guard against null total"
[ ] reviewers/coderabbitai · src/cart/checkout.ts:67 · "extract magic number 4.99"
[?] human/alice           · DESIGN.md · "why not a queue?"   (question, will reply)
[~] coderabbitai          · refactor entire module           (out of scope, skip)
```

### 3. Apply fixes (scope-strict)

Per actionable comment:

1. `Read` the target file first. Always.
2. Group same-file changes through `MultiEdit`.
3. Make exactly the change requested. No bonus rewrites, no style passes, no related cleanups.
4. Check off the comment in your in-memory checklist.

The cardinal rule: **never expand scope**. If a reviewer suggests "this loop could be a `.map`" and you also notice the variable name is bad, leave the variable alone. Renames create review churn and risk regressions outside the original change.

### 4. Reply to non-actionable items

For each `Question` and each `Out of scope` item, post a reply on the original comment thread:

```bash
gh api -X POST repos/{owner}/{repo}/pulls/<pr>/comments/<id>/replies \
  -f body="<reply>"
```

For `Out of scope`, the reply should be specific: "Out of scope for this PR — tracking in #<new-issue>" or "Out of scope — this would belong in the refactor #142 we deferred." Don't dismiss without a paper trail.

### 5. Commit and push

```bash
git add -A
git commit -m "fix: apply PR review feedback"
git push
```

No co-author tags. No automated `Co-authored-by:` lines. The commit should look like a normal fix commit.

### 6. Verify

```bash
gh pr view <pr> --json reviews,statusCheckRollup
```

The expectation after this skill runs: every comment in the `Actionable` bucket is addressed in the new commit, every comment in the `Question` and `Out of scope` buckets has a reply. If a `CHANGES_REQUESTED` review is still active, ask the reviewer to re-review explicitly via `gh pr comment <pr> --body "Addressed. Ready for re-review."` — bots typically re-check on push automatically; humans need the ping.

## Anti-patterns

- Do NOT touch files outside the reviewer's `file:line` references. The blast radius of this skill is what the reviewer asked for, nothing more.
- Do NOT skip a comment because it looks trivial. Reply or fix; never silently ignore.
- Do NOT batch this skill across multiple unrelated PRs. One PR per invocation.
- Do NOT use this skill to suppress a linter / typechecker error the reviewer flagged. Fix the underlying issue.

## Failure modes

- Bot disagreement (two bots flag opposite things on the same line). Reply to both explaining the chosen direction; do not commit a fix that pleases neither.
- Comment references a file no longer in the diff (e.g., file was renamed mid-review). Reply explaining the rename, link the new path.
- All comments are out of scope. Push a single comment on the PR explaining the scope boundary, do not commit anything.

## Composition

- `pr-auto-merge` invokes this skill between bot-idle-watch and re-running CI. It expects the skill to push at least one commit when it returns, otherwise the auto-merge loop exits.
- Standalone use: pair with `gh pr view <pr> --comments` to inspect what you're about to clear, then run this skill.

User: $ARGUMENTS
