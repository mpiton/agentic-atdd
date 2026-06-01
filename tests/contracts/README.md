# tests/contracts/

Cross-skill string-contract checks. Run `./check-contracts.sh` from anywhere; it resolves the repo root itself.

## Why this exists

`tests/fixtures/` catches a single reviewer prompt drifting from its golden. It does **not** catch two skills falling out of agreement with each other. The pipeline's control flow lives in exact strings that one skill emits and another greps:

- reviewers emit `VERDICT: OK` / `VERDICT: REGENERATE`; `red-cycle` and `green-cycle` branch on them.
- `apply-pr-feedback` returns `{pushed_commit, actionable_remaining, all_out_of_scope, replies_posted}`; `pr-auto-merge` branches on `actionable_remaining`.
- `pr-auto-merge` keys on CodeRabbit's `Actionable comments posted` marker.
- `green-cycle` / `pr-auto-merge` promise sub-PRs never target trunk; `hooks/guard-merge.sh` enforces it.
- `red-cycle`, `green-cycle`, `pr-auto-merge` emit `ESCALATED:`; `atdd-run` records `escalations.md`.
- `atdd-run` owns `run-state.json` and reconciles it against GitHub on resume.

Change a producer's wording without updating the consumer and a gate breaks silently. These checks fail loudly instead.

## What it is

Pure `grep` over the SKILL.md files and the hook — no Claude-only primitive, no network, runs in any CI. Exit 0 when every contract holds, 1 otherwise. Every assertion is reported (pass and fail), so one run shows the whole picture.

## When to run

Before publishing any change that touches a reviewer verdict, an escalation phrase, the apply-pr-feedback return shape, the trunk guard, or the run-state model. Wire it into CI alongside whatever harness runs `tests/fixtures/`.

## When a check fails

The failure names the file and the missing string. Either:

1. You renamed a contract string on purpose — update the matching producer/consumer and the assertion together, in one commit.
2. You broke the contract by accident — restore the string the consumer expects.

## Adding a contract

When you add a new producer→consumer handoff that rides on an exact string, add an assertion here in the same change. The cost is one line; the payoff is that the next wording drift fails a test instead of a production run.
