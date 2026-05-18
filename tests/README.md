# tests/

Reviewer-prompt regression suite. Each fixture is a self-contained input set with an `expected.md` golden output. When you change a reviewer SKILL, re-run the suite and inspect drift before shipping.

## Why this exists

Reviewer skills are prompts, not code. A small wording change in `review-architecture/SKILL.md` can silently change every verdict the pipeline produces. Without golden fixtures, prompt regressions ship invisibly.

## Layout

```
tests/
├── README.md
└── fixtures/
    ├── fidelity/                   # for skills/execute/review-fidelity
    │   ├── 01-pass-empty-cart/     # OK case
    │   └── 02-fail-mocked-sut/     # REGENERATE case
    ├── architecture/               # for skills/execute/review-architecture
    │   ├── 01-pass-clean-domain/
    │   └── 02-fail-leaky-adapter/
    └── intent/                     # for skills/execute/review-intent
        ├── 01-pass-minimal/
        └── 02-fail-overengineered/
```

## Fixture contract

Each fixture directory contains:

- **`scenario.feature`** (fidelity & intent only) — the Gherkin scenario the test/diff claims to satisfy.
- **`test.ts`** (fidelity only) — the test source to review.
- **`diff.patch`** (architecture & intent) — the production-code diff to review.
- **`context.md`** (architecture only) — the relevant excerpt of project conventions the reviewer should consult.
- **`expected.md`** — golden output for the reviewer, ending with `VERDICT: OK` or `VERDICT: REGENERATE`.

## Running the suite

Each fixture is fed to its reviewer skill exactly as the pipeline would. There is no test runner shipped with this plugin; pick the comparison strategy that matches your harness.

### Manual / interactive

```text
/review-fidelity   tests/fixtures/fidelity/01-pass-empty-cart/test.ts \
                   tests/fixtures/fidelity/01-pass-empty-cart/scenario.feature
```

Then compare the reviewer's output against `tests/fixtures/fidelity/01-pass-empty-cart/expected.md`. The verdict line must match. The flag set should match modulo wording.

### Scripted (suggested)

Wrap each invocation in your CI runner of choice (a bash loop, a Bun script, a pytest harness). For each fixture:

1. Invoke the corresponding reviewer skill with the fixture inputs.
2. Diff the verdict line against `expected.md`. Fail on mismatch.
3. Optionally diff the flag list (allow wording drift, fail on missing/extra flag categories).

## What "expected" really means

These goldens are **synthetic**: they were authored alongside the SKILL prompts, not produced by running the prompts. They encode the contract the prompts should fulfil.

When a real reviewer run differs from a golden:

1. If the SKILL prompt was intentionally changed, regenerate the golden and commit it with the SKILL change.
2. If the SKILL prompt was unchanged and the verdict flipped, the prompt likely regressed — investigate before publishing.

## Adding fixtures

When you find a real-world case the reviewer mishandled:

1. Minimise it (smallest scenario + test/diff that reproduces the misbehaviour).
2. Drop it under the relevant reviewer's directory as `NN-<pass|fail>-<slug>/`.
3. Write `expected.md` with the verdict you wanted.
4. Iterate on the SKILL prompt until the reviewer matches.

This is how the reviewer prompts get stronger over time.
