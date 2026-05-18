# execute/

Phase 4 (EXECUTION) of the pipeline. RED → GREEN cycle per scenario sub-issue, with bounded auto-correction and two-checkpoint human gate.

## Cycle skills

- **[red-cycle](red-cycle/SKILL.md)** — Generate the failing acceptance test, run `review-fidelity`, auto-correct ×2, escalate on failure.
- **[green-cycle](green-cycle/SKILL.md)** — Generate minimal implementation (YAGNI), run `review-architecture` + `review-intent` in parallel, auto-correct ×2, escalate on failure, gate on human checkpoint #2.

## Reviewers (read-only, composable)

- **[review-fidelity](review-fidelity/SKILL.md)** — Test mirrors its Gherkin scenario (structure / semantics / intent).
- **[review-architecture](review-architecture/SKILL.md)** — Diff respects placement, naming, conventions, domain responsibilities.
- **[review-intent](review-intent/SKILL.md)** — Diff conforms to the scenario, no over-engineering, no hidden side effects.

Each reviewer is callable standalone (`/review-architecture <diff>`), outside the pipeline.
