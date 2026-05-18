---
name: review-fidelity
description: Read-only review verifying that an acceptance test mirrors its Gherkin scenario in structure, semantics, and intent. Returns a verdict OK or REGENERATE. Invoked by red-cycle, also callable standalone on any test/scenario pair.
phase: review
parallel: false
inputs: [scenario-text, test-file]
outputs: [fidelity-report, verdict]
escalation: none
---

# review-fidelity

Test-fidelity reviewer for Phase 4a. Read-only critique of a single test against the Gherkin scenario it claims to implement.

## When to use

- Called by `red-cycle` after a test is generated.
- Standalone: `/review-fidelity <test-file> <scenario-file>` to audit existing tests against their specs.

## Inputs

- `scenario-text` — the `Scenario:` block from the `.feature` file (or the issue body).
- `test-file` — the test source file.

## Output format

Produce a markdown report with three sections, then a verdict line.

### 1. Structure

- The test's logical blocks map 1:1 to `Given / When / Then`.
- The order of assertions matches the order of `Then` clauses.
- Each `Given` step is realized as setup; not skipped, not merged.

Flag with `STRUCTURE: <line> — <issue>`.

### 2. Semantics

- Every concrete value in the scenario (numbers, strings, dates, currencies, identifiers) appears in the test verbatim. No rounding, no rephrasing, no fake substitutes.
- Unit / currency / time-zone of every value match the scenario.
- Identity semantics (case sensitivity, whitespace) match the scenario.

Flag with `SEMANTICS: <expected> vs <actual>`.

### 3. Intent

- No assertion is empty (`expect(true).toBe(true)`, `assert(...)` of a tautology, missing `Then` mapping).
- The system under test is NOT mocked. Collaborators that the scenario references must be real (or test doubles only if the scenario itself describes a stub).
- The test would fail if the production behavior changed in the way the scenario describes (no over-broad assertions like "result is truthy" when the scenario states "result equals 42").
- No assertion the scenario does not state (no scope creep).

Flag with `INTENT: <test location> — <issue>`.

### Verdict

Last line: `VERDICT: OK` (no flags) or `VERDICT: REGENERATE` (any flag).

## Contract

- Read-only. Never edit the test, never edit the scenario.
- Output is deterministic for a given input pair (same flags in same order).
