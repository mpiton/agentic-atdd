# spec/

Phase 1 (INPUT) and Phase 2 (SPEC) of the pipeline. Capture business context, generate Gherkin scenarios, review their coverage.

- **[impact-map](impact-map/SKILL.md)** — Capture user story, actor, action, goal, business rules. Emits `specs/<us-slug>/context.md`.
- **[from-issue](from-issue/SKILL.md)** — Reverse entry: import an existing GitHub issue, parse its body, interview the gaps, tag the issue, emit `context.md`. Use when the team already filed the issue.
- **[from-linear](from-linear/SKILL.md)** — Import a Linear card through MCP, the `linear` CLI or the GraphQL API, interview the gaps, leave one back-link comment, emit `context.md`. Use when the story lives in Linear.
- **[spec-generate](spec-generate/SKILL.md)** — Interview-driven Gherkin generation. One `.feature` per business rule, tagged by test level.
- **[spec-review](spec-review/SKILL.md)** — Read-only review across four axes (branches / coherence / gaps / triangulation). Returns `OK` or `REGENERATE`.
