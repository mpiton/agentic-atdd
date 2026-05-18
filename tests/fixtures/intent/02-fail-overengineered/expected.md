# Expected review-intent output (synthetic golden)

## 1. Conformance
- CONFORMANCE: feature-flag fallback — when `checkout.v2` is disabled, the function returns `accepted` even for an empty cart; this contradicts the scenario's rejection outcome.

## 2. Minimalism (YAGNI)
- OVER-ENGINEERED: `idempotencyKey` parameter — the scenario does not mention idempotency.
- OVER-ENGINEERED: `retryCount` parameter and `> 3` branch — no retry behaviour in the scenario.
- OVER-ENGINEERED: `submissionCache` — caching is not required by the scenario.
- OVER-ENGINEERED: `featureFlags.isEnabled("checkout.v2", ...)` — feature-flag gating not present in the scenario.
- OVER-ENGINEERED: metric `checkout.submit.attempt` — instrumentation not required by the scenario.
- OVER-ENGINEERED: `logger.info / logger.warn` calls — logging not required by the scenario.

## 3. Side effects
- SIDE-EFFECT: module-level `submissionCache: Map` — global mutable state across calls.
- SIDE-EFFECT: `metrics.increment` — hidden I/O to the metrics sink.
- SIDE-EFFECT: `logger.info / warn` — hidden I/O to the log sink.
- SIDE-EFFECT: silent fallback under disabled feature flag hides the rejection that the scenario expects.

## Verdict

VERDICT: REGENERATE
