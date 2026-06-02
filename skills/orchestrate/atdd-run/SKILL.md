---
name: atdd-run
description: End-to-end ATDD pipeline. Use when the user wants to take a user story from impact mapping all the way to merged code, or types /atdd-run.
phase: orchestrate
parallel: true
inputs: [us-slug]
outputs: [merged-prs]
escalation: human-checkpoint
---

# /atdd-run

End-to-end driver for the ATDD pipeline. Chains every phase. Stops at two hard human checkpoints:

1. **Checkpoint #1 — post-spec.** Before any code is written.
2. **Checkpoint #2 — final integration PR.** When all scenario sub-PRs are merged into the integration branch and the final PR `integration → trunk` is opened.

Every scenario sub-PR in between is handled autonomously by [`pr-auto-merge`](../../execute/pr-auto-merge/SKILL.md): CI watch, bot idle watch, `/apply-pr-feedback` on retours (bounded), then auto-merge into the integration branch. No per-scenario human prompt.

## When to use

Trigger when the user provides a user-story slug (e.g. `/atdd-run cart-checkout`) or pastes a US with its business rules.

## Inputs

- `us-slug` — kebab-case identifier (used for filenames and GitHub labels).
- Optional flags:
  - `--sequential` — run reviewers serially instead of in parallel (Codex fallback).
  - `--stage3=<sequential|workflow>` — Stage 3 execution mode. Overrides `.atdd-pipeline.json:stage3_mode`. Default `sequential`. `workflow` is the opt-in parallel path and is ignored (falls back to sequential) when the Workflow tool is unavailable.
  - `--dry-run` — generate scenarios + show issue plan, do not create issues, do not write code.
  - `--from-stage <spec|sync|red|green|auto-merge|final-pr>` — resume from a specific phase.
  - `--no-auto-merge` — temporarily disable `pr-auto-merge` for this run; falls back to the legacy per-scenario human checkpoint #2 inside `green-cycle`.

## Workflow

### Stage 0 — Capture (skill: `impact-map`)

If no `us-slug` provided, run [`impact-map`](../../spec/impact-map/SKILL.md) to elicit the story, actor, action, goal, and business rules. Emit `specs/<us-slug>/context.md`.

### Stage 1 — Spec (skills: `spec-generate`, `spec-review`)

1. Run [`spec-generate`](../../spec/spec-generate/SKILL.md). It MAY interview the user for ambiguities before producing Gherkin.
   - Output: `specs/<us-slug>/*.feature` files (one per scenario, tagged by test level).
2. Run [`spec-review`](../../spec/spec-review/SKILL.md). Read-only review across four axes: branches, coherence, gaps, triangulation.
   - Output: `specs/<us-slug>/review.md`.
3. **Checkpoint #1 — Human gate.** Present the features + review report and ask:
   - `OK` → continue to Stage 2.
   - `REGENERATE <reason>` → loop back to step 1 with the reason as guidance.

### Stage 2 — Sync (skill: `to-issues-atdd`)

Run [`to-issues-atdd`](../../sync/to-issues-atdd/SKILL.md). Idempotent. Creates:

- Parent issue (business goal aggregated from `context.md`).
- User Story issue, linked to parent.
- One sub-issue per `.feature` file, labelled by test level.
- Milestone for the target version (if provided in `context.md`).

Output: a JSON manifest `specs/<us-slug>/issues.json` mapping `scenario-slug → issue-number`.

### Stage 3 — Execute (skills: `red-cycle`, `green-cycle`, `pr-auto-merge`)

Stage 2 already provisioned the integration branch `atdd/<us-slug>/integration` and wrote it to `issues.json`.

Stage 3 has two execution modes. Pick with `.atdd-pipeline.json:stage3_mode` (`sequential` | `workflow`) or the `--stage3=<mode>` flag. **Default is `sequential`** — it is the only mode under Codex and the safe path everywhere.

#### Sequential mode (default)

For each sub-issue in `issues.json.scenarios`, iterate **sequentially** — sub-PRs target the same integration branch, so concurrency would race the merge queue:

1. Run [`red-cycle <issue>`](../../execute/red-cycle/SKILL.md). Generates failing test + runs `review-fidelity`. Bounded auto-correct ×2 then escalate (comment on issue, skip to next scenario).
2. Run [`green-cycle <issue>`](../../execute/green-cycle/SKILL.md). Generates minimal implementation + runs `review-architecture` and `review-intent` (parallel by default). Bounded auto-correct ×2 then escalate. On success: opens a **draft PR targeting the integration branch**.
3. Hand the PR number to [`pr-auto-merge <pr>`](../../execute/pr-auto-merge/SKILL.md). It will:
   - Mark the PR ready.
   - Watch CI to completion.
   - Watch bot reviewers (CodeRabbit, codex, github-actions, etc.) until an `idle_window_minutes` quiet period has elapsed.
   - If actionable bot feedback exists, invoke [`apply-pr-feedback`](../../execute/apply-pr-feedback/SKILL.md) (bundled with this plugin), push, and loop. Capped by `max_fix_iterations`.
   - When CI is green AND no `CHANGES_REQUESTED` AND no actionable bot comments remain: `gh pr merge --squash --delete-branch`.
   - Escalates (comment on PR, leave open) on any timeout / exhausted fix iterations / failing CI it could not repair.
4. After auto-merge succeeds, move to the next scenario. On escalation, record the PR number in `specs/<us-slug>/escalations.md` and continue with remaining scenarios (do NOT abort the whole pipeline).

#### Workflow mode (opt-in, experimental — Claude Code only)

When `stage3_mode == "workflow"` **and** the Workflow tool is available (dynamic workflows are research-preview: a recent Claude Code, a paid plan, not org-disabled), produce all scenarios in parallel and serialize only the merge. This is the substrate that removes the merge-queue serialization from the per-scenario *work* while keeping the merge itself single-lane.

1. **Capability check.** If the Workflow tool is unavailable (Codex, free plan, `disableWorkflows`, older version), **silently fall back to sequential mode above.** Never hard-fail on a missing capability.
2. **Launch the shipped script.** Call the Workflow tool with `scriptPath = ${CLAUDE_PLUGIN_ROOT}/workflows/atdd-stage3.workflow.mjs` and `args = { usSlug, integrationBranch, specsDir, scenarios, conventions }` (flatten `issues.json.scenarios` to `[{slug, issue, branch, level, rule, feature}]`; `conventions` is the once-extracted shared language + relevant ADRs, passed so the N parallel scenario agents don't each re-discover them — a token cache, not a replacement for an agent consulting the ADRs its own diff touches). The script:
   - runs `red-cycle` + `green-cycle` per scenario in an **isolated worktree** (agentType `atdd-scenario`), each branch cut from the integration tip — parallel, no barrier;
   - merges each draft PR through a **single serialized lane** (agentType `atdd-merge`) that rebases onto the live integration tip, re-runs CI, then `pr-auto-merge`s — so the merge queue never races.
3. **Consume the result.** The script returns `{ merged: [slug], escalated: [{slug, issue, pr, reason}] }`. Write each scenario's terminal phase into `run-state.json` and record escalations in `escalations.md`, exactly as sequential mode does.

The human gates stay OUTSIDE the workflow: checkpoint #1 (spec) already happened before Stage 3; checkpoint #2 (final PR) happens in Stage 4 after the workflow returns. Dynamic workflows take no mid-run human input, which is why the gates must bracket Stage 3, never sit inside it. This mode is experimental and opt-in; the sequential loop is the supported default until it has real-repo mileage.

**Write `run-state.json` after every phase boundary** of every scenario (after RED commits, after the draft PR opens, after merge, after escalation), in both modes. This is what makes a multi-hour run crash-resumable rather than restart-from-scratch — see *Run state*. The per-scenario phase transitions are the only durable record of where a fanned-out or interrupted run actually stopped.

There is **no per-scenario human checkpoint** in Stage 3. This is the explicit goal of `auto_merge.enabled == true`.

### Stage 4 — Final integration PR (terminal stop)

After every scenario in `issues.json.scenarios` has either been merged into the integration branch or escalated:

1. **Classify every scenario** from `run-state.json` (see *Run state*) reconciled against GitHub into exactly one of `merged`, `escalated`, `unmerged`:
   - If ANY scenario is `unmerged` (neither merged nor escalated), REFUSE to proceed. The run is not finished; resume the unmerged scenarios first.
   - `escalated` scenarios do NOT block the final PR, but they MUST be surfaced — an escalated scenario is a hole in the user story, and shipping it silently into the trunk PR is the failure this step exists to prevent.
2. Push the integration branch tip (it already has all merged scenario commits via squash merges).
3. Open a single PR `atdd/<us-slug>/integration → trunk_branch`:
   - Title: `[US] <us-slug>: <Goal sentence>`.
   - **Draft status:** open it as a **draft** when `escalated.length > 0`, otherwise ready. A draft can't be fast-merged, which keeps an incomplete US from slipping past the human gate (and dovetails with the trunk-merge guard hook).
   - Body: aggregated summary — goal, list of scenarios (each linking its sub-PR). When `escalated.length > 0`, the body MUST LEAD with a blocking section:

     ```text
     ## ⚠️ Incomplete — <N> scenario(s) escalated, not implemented

     This user story is NOT fully delivered. The following scenarios exhausted
     auto-correction and were skipped:
     - #<issue> <title> — see specs/<us-slug>/escalations.md
     ...
     Resolve or consciously accept each before merging into <trunk_branch>.
     ```

     Then the normal summary and a link to `specs/<us-slug>/` artifacts.
   - Labels: `atdd`, `us/<us-slug>`, `integration`; add `incomplete` when `escalated.length > 0`.
4. **HARD STOP. Checkpoint #2 — Human gate on the trunk PR.** Do NOT invoke `pr-auto-merge` here. `pr-auto-merge` refuses to operate on PRs whose base is `trunk_branch` by contract, and the trunk-merge guard hook blocks it deterministically. Draft status is a guardrail, not the gate — the human still reviews and promotes.
5. Print the PR URL (and, if drafted, the escalated-scenario list) and return.

## Parallelism

When `parallel: true` (default), Stage 3 reviewers run via the `Agent` tool on Claude Code (formerly `Task`; the alias still works). With `--sequential` (or under Codex), reviewers are invoked in series within the same session.

## Failure escalation

An escalation is a first-class signal, not a buried comment. In a sequential run the orchestrator sees each one inline; the moment Stage 3 fans out (workflow mode), a single blocked scenario is easy to miss, so escalation has one contract the orchestrator owns end to end.

Every escalation does four things:

1. **Comment on the GitHub issue / PR** (the sub-skill already does this) with: the failing skill name, the last reviewer report, the auto-correction attempt diffs, and the `ESCALATED:` phrase. GitHub stays the system of record (principle #5).
2. **Append a structured entry to `specs/<us-slug>/escalations.md`** — one block per escalation, machine-readable enough for Stage 4 to classify:

   ```text
   - scenario: <slug> · issue: #<n> · pr: #<n|—> · phase: red | green | auto-merge · at: <iso8601>
     reason: <one line>
     artifacts: specs/<us-slug>/.cycles/<n>/<report>.md
   ```

3. **Mark it in `run-state.json`** — set the scenario's `status: "escalated"` and `phase` to where it died, so resume and Stage 4 both read one source.
4. **Emit a best-effort push** — call `PushNotification` (Claude Code) so a human is actually told a scenario is blocked, e.g. `ATDD <us-slug>: scenario <slug> (#<n>) escalated at <phase> — <reason>`. This is best-effort and **no-op under Codex** (no such tool); it never gates the pipeline.

The pipeline does NOT continue past an escalated sub-issue's work; it moves to the next scenario. It does NOT abort the whole run. Stage 4 then refuses to ready the final PR while any scenario is `unmerged`, and surfaces every `escalated` one in the blocking PR header — so an escalation can't ship silently into the trunk PR.

## Run state

`specs/<us-slug>/run-state.json` is the orchestrator's durable, per-scenario progress record. GitHub Issues remains the system of record (principle #5); this file is the local index that lets a crashed or interrupted run resume at the exact scenario+phase it stopped at, instead of replaying a whole stage. It is also what Stage 4 classifies on.

Shape:

```json
{
  "us_slug": "cart-checkout",
  "integration_branch": "atdd/cart-checkout/integration",
  "updated_at": "<iso8601>",
  "scenarios": {
    "<scenario-slug>": {
      "issue": 130,
      "branch": "atdd/cart-checkout/scenario-130",
      "phase": "red | green | auto-merge | merged | escalated",
      "pr": 142,
      "status": "pending | in_progress | merged | escalated",
      "attempts": { "red_fidelity": 0, "green_review": 0, "fix_iterations": 0 },
      "updated_at": "<iso8601>"
    }
  }
}
```

Two rules:

1. **Write after every transition.** The orchestrator rewrites the relevant scenario entry the moment a phase boundary is crossed (RED committed, draft PR opened, merged, escalated). Never batch the writes to the end — the value is entirely in surviving an interruption.
2. **Reconcile against GitHub on resume, never trust the file blindly.** A crash can land between "merged on GitHub" and "wrote run-state.json". On resume, for each scenario re-derive ground truth from `gh` (`gh pr view <pr> --json state,mergedAt`, `gh issue view <issue> --json state`, branch existence) and correct any drift before continuing. The file is a fast index; GitHub is the truth.

`run-state.json` is seeded from `issues.json` at the start of Stage 3 (every scenario `pending`).

## Outputs

- `specs/<us-slug>/context.md`
- `specs/<us-slug>/*.feature`
- `specs/<us-slug>/review.md`
- `specs/<us-slug>/issues.json` (includes `integration_branch`)
- `specs/<us-slug>/run-state.json` (per-scenario phase/status; the crash-resume index — see *Run state*)
- `specs/<us-slug>/escalations.md` (only if any sub-issue / sub-PR escalated)
- `specs/<us-slug>/.cycles/<issue-number>/auto-merge.log` per scenario (pr-auto-merge timeline).
- One scenario branch + auto-merged sub-PR per successfully completed scenario.
- ONE final PR `atdd/<us-slug>/integration → main`, left OPEN for human review.

## Resume semantics

Two granularities, coarse and fine:

- **Coarse (`--from-stage`)** jumps directly to a stage and reuses the existing artifacts on disk. The skill is idempotent: rerunning a completed stage is a no-op when its outputs already exist (unless `--force` is passed).
- **Fine (per-scenario, automatic).** When Stage 3 is re-entered, the orchestrator reads `run-state.json`, **reconciles each scenario against GitHub** (see *Run state*), and resumes each at its recorded phase: a scenario already `merged` is skipped, one stuck at `auto-merge` re-enters `pr-auto-merge`, one at `green` re-opens/repairs its PR, one `escalated` stays escalated. This is what makes an interrupted multi-hour run resumable at the scenario it died on rather than from the top of the stage.

Background watches (CI / bot-idle) are NOT restored across a session restart, so the resume path re-derives watch state from `gh` rather than any in-memory timer.
