---
name: red-cycle
description: ATDD RED phase. Generate a failing acceptance test at the right level from a scenario sub-issue, run review-fidelity, auto-correct up to 2 times, escalate to human comment on failure. Use when the user types /red <issue-number> or the orchestrator iterates scenarios.
phase: 4-red
parallel: false
inputs: [issue-number]
outputs: [test-file, fidelity-report]
escalation: human-comment-on-issue
---

# /red <issue-number>

Phase 4a of the diagram. Generates ONE failing acceptance test that mirrors the Gherkin scenario stored in the GitHub sub-issue. Runs the fidelity reviewer in a bounded loop.

## When to use

- The orchestrator iterates scenarios from `issues.json`.
- The user types `/red 130` to run a single scenario.

## Inputs

- `<issue-number>` — a GitHub scenario sub-issue created by `to-issues-atdd`.

## Workflow

### 1. Fetch context

```bash
gh issue view <issue-number> --json number,title,body,labels
```

From the labels:

- `level/<use-case|e2e|ui>` — selects the test driver.
- `rule/<R-NN>` — links back to the business rule.
- `us/<us-slug>` — locates `specs/<us-slug>/`.

### 2. Branch

Create and check out a branch: `atdd/<us-slug>/scenario-<issue-number>`.

### 3. Generate the test (attempt 1)

Write ONE test file at the conventional path for the project. Honor the level label:

- `@use-case` — pure domain test, no real I/O, no framework adapters; uses ports / interfaces.
- `@e2e` — exercises the system through its real adapters; database, HTTP, queues are real (test instances).
- `@ui` — UI driver against a rendered view.

The test MUST:

- Re-use the exact `Given / When / Then` wording from the scenario body as comments above the assertions.
- Use the same concrete data values as the scenario (no placeholders, no faker for the values the scenario fixed).
- Make no assertion that the scenario does not state.
- NOT mock the system under test.

Run the test suite. Confirm the new test fails for the **expected** reason (assertion / missing implementation), not for an unrelated reason (compile error, missing import, wrong setup). If it fails for the wrong reason, fix the setup and retry until it fails for the right reason — that fix does NOT consume an auto-correction attempt.

### 4. Fidelity review

Invoke [`review-fidelity`](../review-fidelity/SKILL.md). Pass:

- The Gherkin scenario body.
- The test file content.

Receive a verdict `OK` or `REGENERATE` with reasons.

### 5. Auto-correction loop (max 2)

While the verdict is `REGENERATE` AND the attempt counter is `< 2`:

1. Increment the attempt counter.
2. Rewrite the test addressing every flagged reason. Do not touch production code in this phase.
3. Re-run `review-fidelity`.

### 6. Escalate or hand off

- If `VERDICT: OK` after at most 2 attempts: commit the test on the branch with message `red(<R-NN>): failing test for <scenario title>` and hand off to `green-cycle`.
- If `VERDICT: REGENERATE` after 2 attempts: post a comment on the issue containing:
  - The final reviewer report.
  - The diffs of the 2 attempts.
  - The phrase `ESCALATED: red-cycle exhausted auto-correction.`

  Leave the branch in place for human inspection. Return without invoking `green-cycle`.

## Outputs

- A new test file on the `atdd/<us-slug>/scenario-<issue-number>` branch.
- `specs/<us-slug>/.cycles/<issue-number>/red-fidelity.md` — the final reviewer report.

## Anti-patterns

- Do NOT modify production code in this phase. RED only.
- Do NOT silence the failure (skip / xfail / commented assertion). The test must run and fail loudly.
- Do NOT mock collaborators that the scenario expects to exercise.

## Composition with mattpocock skills

- `tdd` (mattpocock) covers the red/green/refactor philosophy and the anti-pattern of horizontal slicing. This skill is the ATDD-specific, vertical-slice instance: one scenario → one RED → one GREEN. Use `tdd` notes for testing taste; this skill for the pipeline mechanics.
- `diagnose` (mattpocock) is the right escalation tool when a test fails for the wrong reason and the cause is unclear.

