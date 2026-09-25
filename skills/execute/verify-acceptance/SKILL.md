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
- `.atdd-pipeline.json:trunk_branch` (default `main`) for the step 4 diffs, and `integration_branch` from `issues.json`. `atdd-run` passes both; standalone, read them from those files.

## Rule zero — blind to the tests

Until every scenario has a verdict, do NOT open the acceptance test files or the scenario sub-PR diffs. Work only from the Gherkin, `context.md`, the running product, and (for `@use-case` and the `code` fallback) the production code. A verifier that reads the test ends up checking the test again.

## Workflow

### 1. Check out the integration tip

```bash
git status --porcelain --untracked-files=no -- . ':(exclude)specs/<us-slug>'   # must be empty, else abort — never stash or discard someone's work
git fetch origin <integration_branch>
git checkout <integration_branch>
git merge --ff-only origin/<integration_branch>
```

Record the tip SHA for the report. Scenarios to verify: those `merged` in `run-state.json` (standalone without run-state: every scenario in `issues.json` whose sub-PR is merged). Escalated scenarios are listed as `SKIPPED (escalated)` — not implemented, nothing to verify.

The check ignores untracked files and the story folder: `run-state.json`, `escalations.md`, the `.cycles/` reports and a previous pass's `verify.md` are the pipeline's own writes, not someone's work.

Evidence and throwaway scripts go under `specs/<us-slug>/.cycles/verify/`. It holds raw app output and request logs: keep it out of git.

### 2. Start the app

Only when at least one scenario is `@ui` or `@e2e`.

1. Command: `verify.start_command`. Absent → discover it (`package.json` scripts `dev` / `start`, `Makefile` targets `run` / `dev`, `docker compose up`, the README's run section).
2. Check the backends first. Read the env files the command loads. If the database or a third-party service (payment, email, SMS) points at a non-loopback host, or a key is a live one, do not start the app: it is `not started`, reason `non-local backend`. Scenarios send real writes; they must land on local data only.
3. Launch it in the background in its own process group, logging to a file. `set -m` gives the app its own group in bash and zsh (macOS ships no `setsid`), so the cleanup in section 5 stops the whole tree:

   ```bash
   mkdir -p specs/<us-slug>/.cycles/verify
   ( set -m; sh -c '<start_command>' > specs/<us-slug>/.cycles/verify/app.log 2>&1 & echo $! > specs/<us-slug>/.cycles/verify/app.pid )
   ```

4. Wait for readiness, 120 s max: `verify.ready_check` until it exits 0, else poll `verify.base_url` until it answers, else poll the first `http://localhost:<port>` / `http://127.0.0.1:<port>` URL the app prints to `app.log`. The URL the scenarios hit must be loopback.
5. No command found, or not ready in time → the app is `not started`. Record why (the last 20 lines of `app.log`). Runtime scenarios then fall back to the `code` method.

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
  - *Then*: check the response, then the persisted effect through a read path (GET endpoint, CLI query, read-only DB query). Keep the raw request/response log, with `Authorization`, `Cookie` / `Set-Cookie` values and tokens replaced by `<redacted>` before it is written.
- **`@use-case` → method `script`.** A throwaway script that calls the use case with the scenario's concrete values through the project's real wiring (not the acceptance test, not its helpers). Print what each `Then` checks; keep the output.
- **Fallback → method `code`**, when the app is `not started` or the level's method is impossible. Trace the path from the entry point (page, route, command, use case) to the effect, citing `file:line` for each Given/When/Then step. A trace is weaker than an observation; the method label tells the reader so.

Rules for every method:

- Use the scenario's exact values. No placeholders.
- Check what the `Then` lines state, plus anything a user would see break on the way (error page, 5xx, crash, console error).
- Never write to the database to satisfy a `When`. Seed a `Given` directly only when no user-facing path exists, and say so in the report.
- Never run a seed or reset command that drops or truncates data.

Verdict per scenario:

- `PASS` — every `Then` observed (or traced, for `code`) as stated.
- `FAIL` — at least one `Then` contradicted. Quote expected vs observed, point to the evidence.
- `UNVERIFIED` — no conclusion possible (state unreachable, external dependency, path unclear). Give the reason. Never round an `UNVERIFIED` up to `PASS`.

### 4. Regression pass

Scenario verdicts are frozen now; the test files may be read from here on.

1. **Smoke the touched flows.** `git diff --name-only origin/<trunk_branch>...HEAD`, then map the changed files to existing user-facing entry points (pages, routes, CLI commands) that no scenario of this story covers. Exercise at most 5 of them on their happy path, with the step 3 methods. Any error, crash or visibly broken output is a `REGRESSION`. List the entry points skipped past the cap.
2. **Weakened tests.** In `git diff origin/<trunk_branch>...HEAD`, look at test files that already exist on trunk. Flag every deleted test, newly skipped test (`.skip`, `xit`, `@Disabled`, `#[ignore]`, `pytest.mark.skip`, …), and removed or loosened assertion as `WEAKENED-TEST: <file:line>`.
3. **This story's acceptance tests.** They are new, so item 2 cannot see them, yet `pr-auto-merge` and `apply-pr-feedback` touch them after RED. For each merged scenario, diff its test from the RED commit to the tip and flag the same changes:

   ```bash
   git fetch origin pull/<pr>/head
   red=$(git log --format=%H --grep='^red(' origin/<integration_branch>..FETCH_HEAD | tail -1)
   git diff "$red" HEAD -- $(git show --name-only --format= "$red")
   ```

### 5. Stop the app, clean up

Only when this run started the app in section 2:

```bash
pid=$(cat specs/<us-slug>/.cycles/verify/app.pid)
kill -- -"$pid" 2>/dev/null || kill "$pid"
rm specs/<us-slug>/.cycles/verify/app.pid
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
- App start: OK | not started — <last lines of app.log>
- Weakened tests: none | WEAKENED-TEST: <file:line> — <what changed>

VERDICT: OK | PARTIAL | FAIL
```

The last line is the contract `atdd-run` branches on:

- `VERDICT: FAIL` — any scenario `FAIL`, any `REGRESSION`, or any `WEAKENED-TEST`.
- `VERDICT: PARTIAL` — no failure, but at least one scenario `UNVERIFIED`, or a `@ui` / `@e2e` scenario fell back to `code` (a code trace cannot tell whether the app boots).
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
