# Project conventions

- `src/domain/` MUST NOT import any infrastructure SDK (Stripe, DB drivers, HTTP clients).
- The `Cart` term is canonical; do NOT introduce synonyms (no `Basket`).
- Use cases live under `src/<bounded-context>/`, not under `src/domain/`.
- No module-level singletons created from environment variables; collaborators are passed via `deps`.
