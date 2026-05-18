---
name: review-intent
description: Read-only review of an implementation diff for intent conformance - code matches the scenario, no over-engineering, no hidden side effects. Returns OK or REGENERATE. Invoked in parallel with review-architecture by green-cycle.
phase: review
parallel: false
inputs: [diff, scenario-text]
outputs: [intent-report, verdict]
escalation: none
---

# review-intent

Reviewer "intention" from Phase 4b. Read-only critique of a production-code diff against the scenario it claims to satisfy. Runs in parallel with `review-architecture`.

## When to use

- Called by `green-cycle` on the implementation diff.
- Standalone: `/review-intent <diff> <scenario>` to audit any diff against its acceptance scenario.

## Inputs

- `diff` — the staged or committed implementation diff.
- `scenario-text` — the Gherkin scenario the diff is meant to satisfy.

## Output format

Three sections, then a verdict.

### 1. Conformance

- The diff is necessary to make the scenario's test pass.
- Every behavior the scenario describes is reflected in the diff (no missing branch).
- Concrete values from the scenario are honored in the implementation (thresholds, defaults, formats).

Flag with `CONFORMANCE: <scenario line> — <missing or wrong>`.

### 2. Minimalism (YAGNI)

- The diff contains NO logic the scenario does not require.
- No new parameters, fields, configuration knobs, or branches without a corresponding scenario step.
- No premature abstraction (extracted helpers used by only one caller).
- No speculative error handling, logging, metrics, or feature flags absent from the scenario.

Flag with `OVER-ENGINEERED: <symbol> — <why it is not required>`.

### 3. Side effects

- The diff does not mutate state outside what the scenario describes.
- No hidden I/O (network calls, filesystem writes, time-based behavior) absent from the scenario.
- No global state change.
- No silent fallback that hides a failure the scenario would otherwise surface.

Flag with `SIDE-EFFECT: <location> — <unexpected effect>`.

### Verdict

Last line: `VERDICT: OK` (no flags) or `VERDICT: REGENERATE` (any flag).

## Contract

- Read-only. Never edits files.
- Reviews ONLY the diff against the scenario; does not opine on architecture or naming (that is `review-architecture`).
- Flags must be actionable (point to a specific line / symbol / file).
