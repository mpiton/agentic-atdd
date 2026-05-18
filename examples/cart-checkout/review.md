# Spec review — cart-checkout

Subject: scenarios in `examples/cart-checkout/*.feature` against `context.md` (R-01 .. R-05).

## 1. Branches

- R-01: nominal + violation + limit covered. OK.
- R-02: **MISSING: R-02 — no scenario covers a cart whose total is exactly 0.00 EUR (e.g. only items with 0 EUR list price).**
- R-03: **MISSING: R-03 — no scenario covers submission without a shipping address on file.**
- R-04: **MISSING: R-04 — no scenario exercises the out-of-stock rejection.**
- R-05: nominal + violation (declined) + technical (timeout) covered. OK.

## 2. Coherence

- All scenarios use the same actor phrasing ("authenticated customer with a valid shipping address"). OK.
- EUR currency consistent. OK.
- Tags `@use-case` and `@e2e` used; no `@ui` (intentional: this US has no dedicated UI driver). OK.
- No two scenarios in the same file yield contradictory outcomes from identical givens. OK.

## 3. Gaps

- **GAP: R-01 — quantity equal to 1 (the boundary on the accepting side) is covered, quantity 0 and negative are covered; the obvious case "extremely large quantity" (e.g. 10_000) is missing, but this is a stress concern not a behavior gap. Not flagged.**
- **GAP: R-05 — idempotency case missing. If the customer retries submission after a successful authorization, is the order created twice? The rule does not say, so this should be added to `context.md` then a scenario added.**

## 4. Triangulation

- R-01 uses a `Scenario Outline` with two examples for the violation branch. OK.
- R-05 has three distinct scenarios (auth ok / declined / timeout). OK.

## Verdict

VERDICT: REGENERATE
- Re-run `spec-generate` after extending `context.md` for R-02, R-03, R-04, and the R-05 idempotency question. Then re-run `spec-review`.
