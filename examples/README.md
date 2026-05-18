# Worked examples

End-to-end artifact sets produced by the pipeline, used as documentation and as input data for the reviewer fixtures.

## cart-checkout

A small but realistic story: an authenticated customer submitting a cart. Five business rules; two of them are fully fleshed out in `.feature` form (R-01 and R-05).

| File | Pipeline phase |
|---|---|
| [context.md](cart-checkout/context.md) | After `impact-map` |
| [r-01-non-empty-cart.feature](cart-checkout/r-01-non-empty-cart.feature) | After `spec-generate` |
| [r-05-payment-authorization.feature](cart-checkout/r-05-payment-authorization.feature) | After `spec-generate` |
| [review.md](cart-checkout/review.md) | After `spec-review` (verdict: `REGENERATE` — intentionally; demonstrates a real review that catches missing rules R-02/R-03/R-04 and an R-05 idempotency gap) |
| [issues.json](cart-checkout/issues.json) | After `to-issues-atdd` (synthetic issue numbers) |

The review is intentionally `REGENERATE` so the example demonstrates the **read-only critique → human checkpoint → regenerate loop**, not just the happy path. A green run would only differ in the verdict line and the absence of `MISSING / GAP` flags.
