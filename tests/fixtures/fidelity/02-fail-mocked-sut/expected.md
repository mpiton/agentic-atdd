# Expected review-fidelity output (synthetic golden)

## 1. Structure
- STRUCTURE: test body — Given/And/When/Then blocks are not present; the test collapses the entire scenario into a single tautological assertion.

## 2. Semantics
- SEMANTICS: amount 39.98 EUR (scenario) vs absent (test)
- SEMANTICS: line count 2 (scenario) vs absent (test)
- SEMANTICS: card identifier "VISA-DECLINED" (scenario) vs absent (test)
- SEMANTICS: reason "PAYMENT_DECLINED" (scenario) vs absent (test)

## 3. Intent
- INTENT: test body — assertion `expect(result).toBeTruthy()` is vacuous; would pass even if the rule were broken.
- INTENT: test body — the system under test `submitCart` is mocked; the test exercises the mock, not the production code path.
- INTENT: test body — scenario clause "cart still contains the same 2 items totalling 39.98 EUR" is not asserted.

## Verdict

VERDICT: REGENERATE
