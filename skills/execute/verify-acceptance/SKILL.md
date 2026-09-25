---
name: verify-acceptance
description: ATDD Verify stage. Checks that the integrated user story works the way a human would check it, blind to the acceptance tests - drives the real UI for @ui scenarios, the real HTTP/CLI interface for @e2e, a throwaway script for @use-case, and falls back to a code trace only when the app cannot run. Also smoke-checks touched existing flows and flags weakened tests. Use after every scenario is merged into the integration branch, before the final PR, or when the user types /verify-acceptance <us-slug>.
phase: 5-verify
parallel: false
inputs: [us-slug]
outputs: [verify-report, verdict]
escalation: none
---

# /verify-acceptance <us-slug>

Stage 3.5 of the pipeline. Green tests prove the code does what the tests say. This stage checks that the product does what the **spec** says, the way a QA would: open the app, play each scenario by hand, look at the result.

Test results are not evidence here. The same model wrote the Gherkin, the test and the implementation; a wrong reading of the spec passes all three. Verify is the independent look.

## When to use

- `atdd-run` Stage 3.5, once every scenario is merged or escalated, before the final PR.
- Standalone: `/verify-acceptance <us-slug>` on the integration branch, e.g. after a manual fix.

## Inputs

- `<us-slug>` — locates `specs/<us-slug>/` (`context.md`, `*.feature`, `issues.json`, `run-state.json`).
- `.atdd-pipeline.json:verify` — how to launch the app (optional, see *Configuration*).

## Rule zero — blind to the tests

Until every scenario has a verdict, do NOT open the acceptance test files or the scenario sub-PR diffs. Work only from the Gherkin, `context.md`, the running product, and (for `@use-case` and the `code` fallback) the production code. A verifier that reads the test ends up checking the test again.

## Workflow

### 1. Check out the integration tip

```bash
git status --porcelain            # must be empty, else abort — never stash or discard someone's work
git fetch origin <integration_branch>
git checkout <integration_branch>
git merge --ff-only origin/<integration_branch>
```

Record the tip SHA for the report. Scenarios to verify: those `merged` in `run-state.json` (standalone without run-state: every scenario in `issues.json` whose sub-PR is merged). Escalated scenarios are listed as `SKIPPED (escalated)` — not implemented, nothing to verify.

Evidence and throwaway scripts go under `specs/<us-slug>/.cycles/verify/`.

### 2. Start the app

Only when at least one scenario is `@ui` or `@e2e`.

1. Command: `verify.start_command`. Absent → discover it (`package.json` scripts `dev` / `start`, `Makefile` targets `run` / `dev`, `docker compose up`, the README's run section).
2. Launch it in the background in its own process group, logging to a file:

   ```bash
   setsid sh -c '<start_command>' > specs/<us-slug>/.cycles/verify/app.log 2>&1 &
   echo $! > specs/<us-slug>/.cycles/verify/app.pid
   ```

3. Wait for readiness: `verify.ready_check` until it exits 0, else poll `verify.base_url` until it answers. 120 s max.
4. No command found, or not ready in time → the app is `not started`. Record why (the last 20 lines of `app.log`). Runtime scenarios then fall back to the `code` method.

Never point the app at production data or credentials to make it start. Use what the repo's local setup provides; if that is not enough, the app is `not started`.

### 3. Play each scenario like a human

Read the scenario's `.feature`. Pick the method from its level tag:

- **`@ui` → method `ui`, a real browser.** Use whatever the session offers: Playwright or Chrome DevTools MCP tools (look them up with ToolSearch), else a one-off `npx playwright` script.
  - *Given*: reach the state through the UI; else through the app's public API or its documented seed command.
  - *When*: click and type like a user. No JS injection, no direct API call standing in for the UI.
  - *Then*: read what a user sees — visible text, URL, enabled/disabled controls. One screenshot per `Then`.
  - No browser available → method `interface` on the endpoints the page calls, else `code`.
- **`@e2e` → method `interface`, the real external interface**: HTTP with `curl`, the CLI binary, a message on the queue.
  - *Given*: same preference order as `@ui`.
  - *When*: one real request or command.
  - *Then*: check the response, then the persisted effect through a read path (GET endpoint, CLI query, read-only DB query). Keep the raw request/response log.
- **`@use-case` → method `script`.** A throwaway script that calls the use case with the scenario's concrete values through the project's real wiring (not the acceptance test, not its helpers). Print what each `Then` checks; keep the output.
- **Fallback → method `code`**, when the app is `not started` or the level's method is impossible. Trace the path from the entry point (page, route, command, use case) to the effect, citing `file:line` for each Given/When/Then step. A trace is weaker than an observation; the method label tells the reader so.

Rules for every method:

- Use the scenario's exact values. No placeholders.
- Check what the `Then` lines state, plus anything a user would see break on the way (error page, 5xx, crash, console error).
- Never write to the database to satisfy a `When`. Seed a `Given` directly only when no user-facing path exists, and say so in the report.

Verdict per scenario:

- `PASS` — every `Then` observed (or traced, for `code`) as stated.
- `FAIL` — at least one `Then` contradicted. Quote expected vs observed, point to the evidence.
- `UNVERIFIED` — no conclusion possible (state unreachable, external dependency, path unclear). Give the reason. Never round an `UNVERIFIED` up to `PASS`.

### 4. Regression pass

Scenario verdicts are frozen now; the test files may be read from here on.

1. **Smoke the touched flows.** `git diff --name-only origin/<trunk_branch>...HEAD`, then map the changed files to existing user-facing entry points (pages, routes, CLI commands) that no scenario of this story covers. Exercise at most 5 of them on their happy path, with the step 3 methods. Any error, crash or visibly broken output is a `REGRESSION`. List the entry points skipped past the cap.
2. **Weakened tests.** In `git diff origin/<trunk_branch>...HEAD`, look only at test files that already exist on trunk. Flag every deleted test, newly skipped test (`.skip`, `xit`, `@Disabled`, `#[ignore]`, `pytest.mark.skip`, …), and removed or loosened assertion as `WEAKENED-TEST: <file:line>`. The story's new test files are out of scope.

### 5. Stop the app, clean up

```bash
kill -- -"$(cat specs/<us-slug>/.cycles/verify/app.pid)"
```

Delete the throwaway scripts; keep their output, the screenshots and the logs. Leave no change to tracked files.

### 6. Report

Write `specs/<us-slug>/verify.md`:

```markdown
# Verify — <us-slug>

Integration: <integration_branch> @ <sha>
App: started with `<command>` | not started — <reason>

## Scenarios

### #<issue> <title> — PASS · ui
- Given <step>: <what you did>
- When <step>: <what you did>
- Then <step>: <what you saw> — .cycles/verify/<issue>-1.png

### #<issue> <title> — FAIL · interface
- Then <step>: expected <x>, observed <y> — .cycles/verify/<issue>.log

### #<issue> <title> — SKIPPED (escalated)

## Regression
- Smoke: <entry point> — OK | REGRESSION: <what broke>
- Skipped past the cap: <entry points> | none
- Weakened tests: none | WEAKENED-TEST: <file:line> — <what changed>

VERDICT: OK | PARTIAL | FAIL
```

The last line is the contract `atdd-run` branches on:

- `VERDICT: FAIL` — any scenario `FAIL`, any `REGRESSION`, or any `WEAKENED-TEST`.
- `VERDICT: PARTIAL` — no failure, but at least one scenario `UNVERIFIED`.
- `VERDICT: OK` — every verified scenario `PASS`, nothing flagged.

## Configuration

`.atdd-pipeline.json`, every field optional:

```json
"verify": {
  "start_command": "pnpm dev",
  "base_url": "http://localhost:3000",
  "ready_check": "curl -sf http://localhost:3000/health"
}
```

## Anti-patterns

- Do NOT run the test suite and call it verification. CI already did that; this stage exists because it is not enough.
- Do NOT read the acceptance tests before every scenario has a verdict.
- Do NOT fix what you find. This skill never edits production code or tests. A `FAIL` means the scenario's test missed a behavior: the fix goes back through `red-cycle` with the finding, so a test captures it before the code changes.
- Do NOT mark `PASS` without an observation or a trace behind every `Then`.
