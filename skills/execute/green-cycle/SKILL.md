---
name: green-cycle
description: ATDD GREEN phase. Generate the minimal implementation that makes the RED test pass, run review-architecture and review-intent in parallel, auto-correct up to 2 times, then escalate. Use after red-cycle on the same scenario branch, or when the user types /green <issue-number>.
phase: 4-green
parallel: true
inputs: [issue-number]
outputs: [implementation-diff, architecture-report, intent-report]
escalation: human-comment-on-issue
---

# /green <issue-number>

Phase 4b of the diagram. Generates the minimal production code that makes the failing test from `red-cycle` pass. Runs two reviewers in parallel (`review-architecture` and `review-intent`) in a bounded loop. Ends at human checkpoint #2.

## When to use

- Right after `red-cycle` produced a failing test for the same issue number.
- Standalone via `/green <issue-number>` when the branch already has a failing acceptance test committed.

## Inputs

- `<issue-number>` — same scenario sub-issue as `red-cycle`.

## Preconditions

- Current branch is `atdd/<us-slug>/scenario-<issue-number>`.
- Exactly one failing test exists for this scenario.
- Whole suite runs; only the new test is red.

If any precondition fails, abort with a clear message; do not modify code.

## Workflow

### 1. Implement (attempt 1)

Write the minimal production code to make the failing test pass. **YAGNI strict**:

- Do not add any branch the test does not force.
- Do not add fields, parameters, or error variants the test does not assert.
- Do not refactor neighbouring code that was already green.
- Do not change other tests.

Run the suite. Confirm: every previously green test still passes AND the new test passes.

### 2. Parallel review

Invoke both reviewers. On Claude Code, dispatch them in parallel via the `Task` tool. With `--sequential` (or under Codex), invoke them serially in the same session.

- [`review-architecture`](../review-architecture/SKILL.md) — verifies placement, naming, conventions, domain responsibilities.
- [`review-intent`](../review-intent/SKILL.md) — verifies conformance to the scenario, minimalism, no hidden side effects.

Each returns a verdict `OK` or `REGENERATE` with reasons.

### 3. Auto-correction loop (max 2)

If EITHER reviewer returns `REGENERATE`:

1. Increment the attempt counter.
2. Rewrite the production code addressing every flagged reason from BOTH reports. Do not touch the test.
3. Re-run the suite. New test must still pass; previously green tests must still pass.
4. Re-invoke both reviewers (parallel as above).

Stop when both report `OK`, or when the counter reaches 2.

### 4. Escalate or hand off

- If both `VERDICT: OK` within 2 attempts: commit with message `green(<R-NN>): minimal impl for <scenario title>`. Push the branch. Open a draft PR linking the scenario issue.
  - **Base branch:** read `integration_branch` from `specs/<us-slug>/issues.json` (fallback: resolve via `.atdd-pipeline.json:integration_branch_pattern`). The PR MUST target the integration branch, NEVER `trunk_branch` directly.
  - Command shape: `gh pr create --draft --base <integration_branch> --head <scenario_branch> --title "..." --body "Closes #<issue-number>"`.
- If either reviewer is still `REGENERATE` after 2 attempts: post a comment on the issue containing:
  - Both final reviewer reports.
  - The diffs of the 2 attempts.
  - The phrase `ESCALATED: green-cycle exhausted auto-correction.`

  Leave the branch in place. Do NOT open a PR. Return.

### 5. Hand off to auto-merge (default) or human checkpoint #2 (fallback)

If `.atdd-pipeline.json:auto_merge.enabled == true` (default):

- Hand off the PR number to [`pr-auto-merge`](../pr-auto-merge/SKILL.md). No human prompt at this point.
- `pr-auto-merge` will mark the PR ready, watch CI + bots, invoke `/apply-pr-feedback` on retours (bounded), and merge into the integration branch on success.

If `auto_merge.enabled == false`, fall back to a human checkpoint:

- Present the full diff (test + implementation) and ask:
  - `MERGE` → mark the PR ready, merge, close the scenario issue with a comment linking the PR.
  - `CHANGE <reason>` → re-enter step 1 with the reason appended as additional review feedback (consumes one auto-correction attempt).
  - `SKIP` → leave the PR draft, leave the branch, move on.

## Outputs

- Implementation diff on the branch.
- `specs/<us-slug>/.cycles/<issue-number>/green-architecture.md`
- `specs/<us-slug>/.cycles/<issue-number>/green-intent.md`
- Draft PR (on success) or escalation comment (on failure).

## Anti-patterns

- Do NOT touch the test in this phase. The test is the contract.
- Do NOT add speculative code "for future scenarios". The next scenario will trigger its own RED/GREEN.
- Do NOT silence reviewer flags by suppressing the linter / typechecker; address the underlying issue.

## Composition with mattpocock skills

- `improve-codebase-architecture` (mattpocock) is the right follow-up tool when several green-cycles in the same module reveal an emerging shape. Run it between scenarios, never during a cycle (would invalidate the minimal-diff invariant of this phase).
- `zoom-out` (mattpocock) is useful before a checkpoint #2 review when the human reviewer wants the diff explained in system context, not just locally.

