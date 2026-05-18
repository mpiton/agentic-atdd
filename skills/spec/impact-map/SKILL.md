---
name: impact-map
description: Capture a user story, actor, action, goal, and business rules from the user. Use when the user wants to start a new feature and has not yet provided structured business context, or types /impact-map.
phase: 1-input
parallel: false
inputs: []
outputs: [context-md]
escalation: none
---

# /impact-map

Elicit and structure the business context behind a user story before any code or scenarios are written. This is the "board d'impact mapping" of the pipeline: actor → goal → action → user story → business rules.

## When to use

- Start of a new feature.
- The user pastes a half-formed story like "we need cart checkout" with no rules.
- Upstream of `spec-generate`.

## Inputs

None required. Pull everything from the user via grilling.

## Workflow

### 1. Grill for the impact map (mandatory)

Ask the user, in order:

1. **Actor.** Who triggers this? Be specific (role, not "user").
2. **Goal (impact).** What outcome does the actor want? Phrase as a business impact, not a UI behavior.
3. **Action.** What does the actor do to reach the goal?
4. **User story.** Compose: `As a <actor>, I want to <action>, so that <goal>.`
5. **Business rules.** Enumerate every rule that constrains the action. Press for:
   - Authorization rules (who can/cannot).
   - Boundary / limit rules (max amount, time windows).
   - Conflict rules (what's incompatible).
   - Lifecycle / state rules (pre/post conditions).
6. **Target milestone / version** (optional).
7. **Non-goals.** What is explicitly out of scope?

Stop and ask if any answer is vague. Do not infer rules from your training; surface ambiguities as questions.

### 2. Emit `context.md`

Write `specs/<us-slug>/context.md` with this structure:

```markdown
# <us-slug>

## Actor
<role>

## Goal
<business outcome>

## Action
<what the actor does>

## User story
As a <actor>, I want to <action>, so that <goal>.

## Business rules
- <id: short label> — <rule>
- ...

## Non-goals
- ...

## Milestone
<version or "TBD">
```

Rule IDs follow `R-<NN>` (e.g. `R-01`). They will be reused as tags on Gherkin scenarios.

## Output

- `specs/<us-slug>/context.md`

## Handoff

Next skill in the pipeline: [`spec-generate`](../spec-generate/SKILL.md). It reads `context.md` and produces Gherkin scenarios per rule.

## Composition with mattpocock skills

If the project already uses the mattpocock skill set:

- `grill-with-docs` is a stronger interview engine than the plain grilling described above; invoke it as a sub-tool to gather rules and update `CONTEXT.md` / ADRs in the same session, then transcribe the result into `specs/<us-slug>/context.md`.
- `to-prd` produces a sibling PRD document. If used, link the PRD path from `context.md`.

