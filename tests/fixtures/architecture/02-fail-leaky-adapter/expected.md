# Expected review-architecture output (synthetic golden)

## 1. Structure (placement)
- PLACEMENT: src/domain/cart.ts — imports `stripe` (adapter SDK) into the domain layer; violates the inward-only dependency rule.
- PLACEMENT: src/domain/cart.ts — defines `submitBasket`, a use case, inside the domain folder; use cases belong under `src/<bounded-context>/`.

## 2. Naming and conventions
- NAMING: submitBasket — uses synonym "Basket" for the canonical term "Cart".
- NAMING: input.basket — parameter name reinforces the disallowed synonym.

## 3. Responsibilities
- RESPONSIBILITY: src/domain/cart.ts — mixes domain type definition with use-case orchestration and infrastructure I/O in a single module.
- RESPONSIBILITY: module-level `stripe` — creates an infrastructure singleton from `process.env`, bypassing the `deps`-injection convention.

## Verdict

VERDICT: REGENERATE
