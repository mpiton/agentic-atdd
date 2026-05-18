---
name: atdd-run
description: End-to-end ATDD pipeline. Use when the user wants to take a user story from impact mapping all the way to merged code, or types /atdd-run.
phase: orchestrate
parallel: true
inputs: [us-slug]
outputs: [merged-prs]
escalation: human-checkpoint
---

# /atdd-run

End-to-end driver for the ATDD pipeline. Chains every phase. Stops at two hard human checkpoints:

1. **Checkpoint #1 — post-spec.** Before any code is written.
2. **Checkpoint #2 — final integration PR.** When all scenario sub-PRs are merged into the integration branch and the final PR `integration → trunk` is opened.

Every scenario sub-PR in between is handled autonomously by [`pr-auto-merge`](../../execute/pr-auto-merge/SKILL.md): CI watch, bot idle watch, `/fix-pr-comments` on retours (bounded), then auto-merge into the integration branch. No per-scenario human prompt.

## When to use

Trigger when the user provides a user-story slug (e.g. `/atdd-run cart-checkout`) or pastes a US with its business rules.

## Inputs

- `us-slug` — kebab-case identifier (used for filenames and GitHub labels).
- Optional flags:
  - `--sequential` — run reviewers serially instead of in parallel (Codex fallback).
  - `--dry-run` — generate scenarios + show issue plan, do not create issues, do not write code.
  - `--from-stage <spec|sync|red|green|auto-merge|final-pr>` — resume from a specific phase.
  - `--no-auto-merge` — temporarily disable `pr-auto-merge` for this run; falls back to the legacy per-scenario human checkpoint #2 inside `green-cycle`.

## Workflow

### Stage 0 — Capture (skill: `impact-map`)

If no `us-slug` provided, run [`impact-map`](../../spec/impact-map/SKILL.md) to elicit the story, actor, action, goal, and business rules. Emit `specs/<us-slug>/context.md`.

### Stage 1 — Spec (skills: `spec-generate`, `spec-review`)

1. Run [`spec-generate`](../../spec/spec-generate/SKILL.md). It MAY interview the user for ambiguities before producing Gherkin.
   - Output: `specs/<us-slug>/*.feature` files (one per scenario, tagged by test level).
2. Run [`spec-review`](../../spec/spec-review/SKILL.md). Read-only review across four axes: branches, coherence, gaps, triangulation.
   - Output: `specs/<us-slug>/review.md`.
3. **Checkpoint #1 — Human gate.** Present the features + review report and ask:
   - `OK` → continue to Stage 2.
   - `REGENERATE <reason>` → loop back to step 1 with the reason as guidance.

### Stage 2 — Sync (skill: `to-issues-atdd`)

Run [`to-issues-atdd`](../../sync/to-issues-atdd/SKILL.md). Idempotent. Creates:

- Parent issue (business goal aggregated from `context.md`).
- User Story issue, linked to parent.
- One sub-issue per `.feature` file, labelled by test level.
- Milestone for the target version (if provided in `context.md`).

Output: a JSON manifest `specs/<us-slug>/issues.json` mapping `scenario-slug → issue-number`.

### Stage 3 — Execute (skills: `red-cycle`, `green-cycle`, `pr-auto-merge`)

Stage 2 already provisioned the integration branch `atdd/<us-slug>/integration` and wrote it to `issues.json`.

For each sub-issue in `issues.json.scenarios` (iterate sequentially — sub-PRs target the same integration branch, so concurrency would race the merge queue):

1. Run [`red-cycle <issue>`](../../execute/red-cycle/SKILL.md). Generates failing test + runs `review-fidelity`. Bounded auto-correct ×2 then escalate (comment on issue, skip to next scenario).
2. Run [`green-cycle <issue>`](../../execute/green-cycle/SKILL.md). Generates minimal implementation + runs `review-architecture` and `review-intent` (parallel by default). Bounded auto-correct ×2 then escalate. On success: opens a **draft PR targeting the integration branch**.
3. Hand the PR number to [`pr-auto-merge <pr>`](../../execute/pr-auto-merge/SKILL.md). It will:
   - Mark the PR ready.
   - Watch CI to completion.
   - Watch bot reviewers (CodeRabbit, codex, github-actions, etc.) until an `idle_window_minutes` quiet period has elapsed.
   - If actionable bot feedback exists, invoke [`fix-pr-comments`](../../../../skills/fix-pr-comments/SKILL.md) (user-level skill), push, and loop. Capped by `max_fix_iterations`.
   - When CI is green AND no `CHANGES_REQUESTED` AND no actionable bot comments remain: `gh pr merge --squash --delete-branch`.
   - Escalates (comment on PR, leave open) on any timeout / exhausted fix iterations / failing CI it could not repair.
4. After auto-merge succeeds, move to the next scenario. On escalation, record the PR number in `specs/<us-slug>/escalations.md` and continue with remaining scenarios (do NOT abort the whole pipeline).

There is **no per-scenario human checkpoint** in Stage 3. This is the explicit goal of `auto_merge.enabled == true`.

### Stage 4 — Final integration PR (terminal stop)

After every scenario in `issues.json.scenarios` has either been merged into the integration branch or escalated:

1. Refuse to proceed if any non-escalated scenario is still unmerged.
2. Push the integration branch tip (it already has all scenario commits via squash merges).
3. Open a single PR `atdd/<us-slug>/integration → trunk_branch`:
   - Title: `[US] <us-slug>: <Goal sentence>`.
   - Body: aggregated summary — goal, list of scenarios (each linking its sub-PR), open escalations, link to `specs/<us-slug>/` artifacts.
   - Labels: `atdd`, `us/<us-slug>`, `integration`.
4. **HARD STOP. Checkpoint #2 — Human gate on the trunk PR.** Do NOT invoke `pr-auto-merge` here. `pr-auto-merge` refuses to operate on PRs whose base is `trunk_branch` by contract.
5. Print the PR URL and return.

## Parallelism

When `parallel: true` (default), Stage 3 reviewers run via the `Task` tool on Claude Code. With `--sequential` (or under Codex), reviewers are invoked in series within the same session.

## Failure escalation

Every escalation produces a comment on the relevant GitHub issue containing:

- The failing skill name.
- The last reviewer report.
- The two auto-correction attempts (diffs).

The pipeline does NOT continue past an escalated sub-issue; it moves to the next sub-issue and records the skipped one in `specs/<us-slug>/escalations.md`.

## Outputs

- `specs/<us-slug>/context.md`
- `specs/<us-slug>/*.feature`
- `specs/<us-slug>/review.md`
- `specs/<us-slug>/issues.json` (includes `integration_branch`)
- `specs/<us-slug>/escalations.md` (only if any sub-issue / sub-PR escalated)
- `specs/<us-slug>/.cycles/<issue-number>/auto-merge.log` per scenario (pr-auto-merge timeline).
- One scenario branch + auto-merged sub-PR per successfully completed scenario.
- ONE final PR `atdd/<us-slug>/integration → main`, left OPEN for human review.

## Resume semantics

`--from-stage` jumps directly to that stage but reuses the existing artifacts on disk. The skill is idempotent: rerunning a completed stage is a no-op when its outputs already exist (unless `--force` is passed).
