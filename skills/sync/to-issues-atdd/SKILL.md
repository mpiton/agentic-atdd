---
name: to-issues-atdd
description: Idempotent sync of ATDD spec artifacts to GitHub Issues. Creates parent / user story / one sub-issue per scenario, with test-level labels and milestone. Re-runnable without duplication. Use after spec-review verdict is OK.
phase: 3-sync
parallel: false
inputs: [context-md, feature-files, review-md]
outputs: [issues-json]
escalation: none
---

# /to-issues-atdd

Phase 3 SYNC of the diagram. Reads the validated spec artifacts and produces a GitHub Issues hierarchy via `gh` CLI. Idempotent.

## When to use

After `spec-review` returned `VERDICT: OK` and the human approved at checkpoint #1.

## Prerequisites

- `gh` authenticated against the target repo (`gh auth status`).
- Current directory is inside a git repo with a GitHub remote, OR a `--repo owner/name` flag is passed.

## Inputs

- `specs/<us-slug>/context.md`
- `specs/<us-slug>/*.feature`
- `specs/<us-slug>/review.md`

## Issue hierarchy

```
[Goal] <Goal sentence from context.md>     # parent
  └─ [US] <us-slug>                         # user story, references parent in body
       ├─ [Scenario] <scenario-1 title>     # one per .feature scenario
       ├─ [Scenario] <scenario-2 title>
       └─ ...
```

All issues are tagged with the global label `atdd` plus a slug label `us/<us-slug>`. Scenario issues additionally carry:

- A test-level label: `level/use-case` | `level/e2e` | `level/ui` (from the Gherkin tag).
- A branch label: `branch/nominal` | `branch/violation` | `branch/auth` | `branch/technical` | `branch/limit`.
- A rule label: `rule/<R-NN>`.

Optional: `milestone` from `context.md` if not "TBD".

## Idempotency contract

Before creating any issue, search for existing issues with the same title prefix AND label set in the target repo:

```bash
gh issue list --label "atdd" --label "us/<us-slug>" --state all --json number,title,labels
```

- If a matching issue already exists, REUSE its number.
- If it exists but its body has drifted from the current artifact content, post a comment with the new body (do not overwrite the description, do not duplicate).
- Never create a second parent / US / scenario issue for the same artifact.

After the run, every artifact maps to exactly one issue number.

## Workflow

1. **Provision the integration branch.** Resolve the integration branch name from `.atdd-pipeline.json:integration_branch_pattern` (e.g. `atdd/<us-slug>/integration`). If it does not already exist on the remote, create it from `trunk_branch`:

   ```bash
   git fetch origin <trunk>
   git push origin "origin/<trunk>:refs/heads/atdd/<us-slug>/integration"
   ```

   Idempotent: skip if the branch already exists. This branch is the merge target for every scenario sub-PR opened later by `green-cycle`.

2. Ensure required labels exist (`gh label create --force` for each). Skip silently if they already exist.
3. Create or reuse the parent issue. Title: `[Goal] <Goal>`. Body: the relevant sections of `context.md`.
4. Create or reuse the user story issue. Title: `[US] <us-slug>`. Body: the user-story sentence + a link to the parent.
5. For each `.feature` file, parse the `Scenario:` lines. For each scenario, create or reuse a sub-issue:
   - Title: `[Scenario] <scenario title>`.
   - Body: the full `Scenario:` block (Gherkin), plus a link to the US issue.
   - Labels: as described above.
6. Assign milestone if any.
7. Emit `specs/<us-slug>/issues.json`:

```json
{
  "parent": 123,
  "us": 124,
  "integration_branch": "atdd/<us-slug>/integration",
  "scenarios": {
    "<scenario-slug>": { "issue": 130, "feature": "specs/<us-slug>/<rule-slug>.feature", "level": "use-case", "rule": "R-01" }
  }
}
```

## Output

- `specs/<us-slug>/issues.json`

## Handoff

Next: [`red-cycle`](../../execute/red-cycle/SKILL.md) per scenario issue. The orchestrator iterates `issues.json.scenarios`.

## Non-goals

- Do not create PRs.
- Do not assign reviewers.
- Do not modify the spec artifacts (read-only on `context.md` and `.feature`).

## Composition with mattpocock skills

- `to-issues` (mattpocock) is a general-purpose, tracer-bullet issue splitter for any plan or PRD. This skill is the ATDD-specific variant: the hierarchy is fixed (parent / US / scenarios), the labels are pre-defined, and the input is the `.feature` artifacts rather than free-form scope. Use `to-issues` when the input is a PRD or arbitrary plan; this skill when the input is the spec output of `spec-review`.
- `triage` (mattpocock) is the right next step on scenario sub-issues before `red-cycle` if the project relies on a triage state machine.

