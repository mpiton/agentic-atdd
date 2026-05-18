# Expected review-architecture output (synthetic golden)

## 1. Structure (placement)
- No flags. New `submitCart` lives under `src/checkout/`, importing types from `src/domain/` and ports from `src/ports/`. Layering respected.

## 2. Naming and conventions
- No flags. Shared-language terms used verbatim. Named-object arguments. No "Basket" synonym.

## 3. Responsibilities
- No flags. Use case orchestrates; payment authorization delegated through the `PaymentGateway` port; domain types come from `domain/`.

## Verdict

VERDICT: OK
