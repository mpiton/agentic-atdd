# Project conventions (excerpt of CONTEXT.md used for the fixture)

- Domain types live under `src/domain/`.
- Adapter ports (boundaries) live under `src/ports/`.
- Application use cases live under `src/<bounded-context>/`.
- A use case must receive infrastructure collaborators via a `deps` argument; no module-level singletons.
- Identifiers use the shared language: `Cart`, `Customer`, `SubmissionResult` (no synonyms like `Basket` or `Order`).
- Public functions use named-object arguments to stay self-documenting at call sites.
