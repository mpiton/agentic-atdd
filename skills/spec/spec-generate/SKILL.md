---
name: spec-generate
description: Generate Gherkin acceptance scenarios from a context.md, with mandatory interview for ambiguities, concrete data, and test-level tags. Use after impact-map, or when the user provides a user story and rules and asks for scenarios.
phase: 2-spec
parallel: false
inputs: [context-md]
outputs: [feature-files]
escalation: none
---

# /spec-generate

Generate Gherkin scenarios from `specs/<us-slug>/context.md`. The pipeline calls this skill in Phase 2 §3 of the diagram.

## When to use

- After `impact-map` produced `context.md`.
- When the user pastes a structured story + rules and asks for acceptance scenarios.

## Inputs

- `specs/<us-slug>/context.md` (see [`impact-map`](../impact-map/SKILL.md)).

## Workflow

### 1. Interview (mandatory before generation)

Read `context.md`. Identify every ambiguity in the business rules — DO NOT guess. For each ambiguity, ask one focused question. Examples of things that always require a question if not already explicit:

- Numeric thresholds without units (`"limit of 100"` — 100 what?).
- Implicit time zones, date formats, currency.
- Identity / equality semantics (case sensitivity, trimming).
- Default values for omitted fields.
- Behavior on the boundary itself (`<=` vs `<`).

Stop the interview only when every rule can be expressed with concrete, unambiguous data.

### 2. Generate scenarios

For each business rule `R-NN`, produce one `.feature` file at `specs/<us-slug>/<rule-slug>.feature`.

Each file MUST contain scenarios covering at least:

- **Nominal** path (tag: `@nominal`).
- **Violation** of the rule (tag: `@violation`).
- **Authorization** path if the rule involves access (tag: `@auth`).
- **Technical** / integration edge if applicable (tag: `@technical`).
- **Limits / boundaries** for any numeric rule (tag: `@limit`).

Use **concrete data** (real values, not placeholders). Example: prefer `Given the cart contains 3 items at 19.99 EUR` over `Given some items in the cart`.

Add a `# Rule: R-NN` comment at the top of each feature file so traceability survives renames.

Triangulation: if a rule is complex, produce **multiple examples** (Scenario Outline with `Examples:`) rather than a single example.

### 3. Test-level tag

Tag each scenario by the appropriate test level:

- `@use-case` — pure domain / use case test.
- `@e2e` — end-to-end with the real adapters.
- `@ui` — UI driver (Playwright, RTL, etc.).

If unsure, ask the user before generating.

## Outputs

- `specs/<us-slug>/<rule-slug>.feature` — one per business rule.

## Handoff

Next: [`spec-review`](../spec-review/SKILL.md) on the generated `.feature` files.

## Anti-patterns

- **Don't** generate scenarios for rules that are not in `context.md`. Push back, ask `impact-map` to capture them first.
- **Don't** invent assertions; every assertion must trace to a rule.
- **Don't** mock the system under test in the scenario data. Scenarios describe behavior, not implementation.
