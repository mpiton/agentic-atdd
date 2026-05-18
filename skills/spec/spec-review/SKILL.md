---
name: spec-review
description: Read-only review of generated Gherkin scenarios across four axes (branches, coherence, gaps, triangulation). Produces a verdict OK or REGENERATE. Use after spec-generate.
phase: 2-spec
parallel: false
inputs: [context-md, feature-files]
outputs: [review-md, verdict]
escalation: human-checkpoint
---

# /spec-review

Reviewer "couverture" of Phase 2 §4. Read-only critique of the `.feature` files produced by `spec-generate`. Never modifies them.

## When to use

After `spec-generate`. Before the human checkpoint #1.

## Inputs

- `specs/<us-slug>/context.md`
- `specs/<us-slug>/*.feature`

## Workflow

Produce `specs/<us-slug>/review.md` with exactly four sections, in this order. End with a verdict line.

### 1. Branches

For each rule `R-NN`, check that the scenarios cover all relevant branches:

- Nominal path present?
- Violation of the rule present?
- Auth dimension covered (if the rule mentions actors / roles)?
- Technical edge covered (if the rule mentions integration / external systems)?
- Numeric / time / size limits exercised at the boundary (`<`, `<=`, `>`, `>=`)?

Flag any missing branch with `MISSING: R-NN — <branch>`.

### 2. Coherence

- No two scenarios in the same `.feature` file produce the same outcome from the same `Given`.
- No contradiction between scenarios across files (e.g. rule A says "always X", rule B's scenario produces "not X" in a state where A applies).
- Tags match the test-level convention (`@use-case | @e2e | @ui`).
- Concrete data is reused consistently (same actor name, same currency, same date format).

Flag with `INCOHERENCE: <where> — <what>`.

### 3. Gaps

Re-read `context.md`. For every rule, ask: "What's the obvious case a developer would forget?"

- Empty input.
- Maximum input.
- Concurrent / race scenario if the rule has timing.
- Idempotency case if the action is repeatable.
- Rollback case if the action has state.

Flag with `GAP: R-NN — <obvious case missing>`.

### 4. Triangulation

For each rule that is non-trivial (more than one boolean), check there are **multiple examples** (Scenario Outline + `Examples:`). A single example for a complex rule is a triangulation defect.

Flag with `TRIANGULATION: R-NN — needs more examples (currently <count>)`.

### Verdict

Last line of `review.md` is one of:

- `VERDICT: OK` — zero `MISSING`, zero `INCOHERENCE`, zero `GAP`, zero `TRIANGULATION` flag.
- `VERDICT: REGENERATE` — at least one flag. The review report is the regeneration brief.

## Output

- `specs/<us-slug>/review.md`

## Read-only contract

This skill MUST NOT edit `.feature` files. If the verdict is `REGENERATE`, the orchestrator (or the user) re-invokes `spec-generate` with this report attached.
