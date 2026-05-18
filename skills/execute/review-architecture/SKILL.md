---
name: review-architecture
description: Read-only review of an implementation diff for structural quality - placement, naming, project conventions, and domain responsibilities. Returns OK or REGENERATE. Invoked in parallel with review-intent by green-cycle, also callable standalone on a PR or diff.
phase: review
parallel: false
inputs: [diff, project-conventions]
outputs: [architecture-report, verdict]
escalation: none
---

# review-architecture

Reviewer "architecture" from Phase 4b. Read-only critique of a production-code diff. Runs in parallel with `review-intent`.

## When to use

- Called by `green-cycle` on the implementation diff produced by attempt N.
- Standalone: `/review-architecture <diff-or-pr>` to audit any change.

## Inputs

- `diff` — the staged or committed diff to review.
- Project conventions, discovered from the repo:
  - `CONTEXT.md` (shared language).
  - `docs/adr/` (architecture decision records).
  - Existing file structure under the touched module.

## Output format

Three sections, then a verdict.

### 1. Structure (placement)

- New files live in the layer matching their responsibility (e.g. domain logic in `domain/`, adapters in `infra/`).
- Public exports from a module match the module's contract; nothing leaks across layer boundaries.
- The diff respects the import direction conventions of the project (no inward dependencies from infra into domain, etc.).

Flag with `PLACEMENT: <path> — <issue>`.

### 2. Naming and conventions

- Identifiers use the project's shared language (terms from `CONTEXT.md`). No synonyms, no jargon drift.
- File naming, casing, and pluralization follow the local convention.
- Public type / function signatures match the style of neighbouring code (parameter order, error vs result, sync vs async).

Flag with `NAMING: <symbol> — <issue>`.

### 3. Responsibilities

- Each new function / class has a single coherent responsibility.
- Domain logic is in domain code; orchestration in application services; I/O in adapters. No mixing.
- No business rule duplicated across layers.
- Existing patterns are reused; the diff does not introduce a parallel mechanism for a thing the codebase already does.

Flag with `RESPONSIBILITY: <symbol> — <issue>`.

### Verdict

Last line: `VERDICT: OK` (no flags) or `VERDICT: REGENERATE` (any flag).

## Contract

- Read-only. Never edits files.
- Reviews ONLY the diff; does not propose unrelated refactors of pre-existing code.
- Flags must be actionable (point to a specific line / symbol / file).
