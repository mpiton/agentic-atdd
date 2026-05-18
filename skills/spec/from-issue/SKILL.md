---
name: from-issue
description: Import an existing GitHub issue into the ATDD pipeline. Parses the issue body into a context.md, interviews the user to fill gaps, tags the issue, and hands off to spec-generate. Use when the user has an existing issue tracker entry they want to drive through the pipeline.
phase: 1-input
parallel: false
inputs: [issue-number]
outputs: [context-md, tagged-issue]
escalation: none
---

# /from-issue <issue-number>

Reverse-direction entry point. Most pipelines start from a blank story (`impact-map`); this skill starts from an issue that already exists in GitHub and back-fills the structured artifacts the pipeline needs.

## When to use

- The team already opened an issue with prose acceptance criteria.
- You want to drive that existing issue through `red-cycle` / `green-cycle` without recreating it.
- The issue body has some structure (Goal / Acceptance / Files) but is not Gherkin.

If the issue body already contains Gherkin (`Scenario:` blocks), skip this skill and call `/red <issue-number>` directly.

## Inputs

- `<issue-number>` — GitHub issue number in the current repo, or `--repo owner/name <issue-number>` to target another repo.

## Workflow

### 1. Fetch the issue

```bash
gh issue view <issue-number> --json number,title,body,labels,milestone,assignees
```

### 2. Derive the slug

Build a `us-slug` from the title:

- If the title starts with a ticket prefix like `T-235:` or `[FEAT-12]`, keep it: `t-235-<rest-kebab>`.
- Otherwise kebab-case the title and trim to 6 significant words.

Present the proposed slug to the user; accept an override.

### 3. Parse known sections

Look for these headings in the body. Use what you find; do NOT invent content.

| Heading found | Maps to |
|---|---|
| `## Goal` / `## Description` / `## Context` | `## Goal` in `context.md` |
| `## Acceptance criteria` / `## Acceptance` / `## Definition of done` | seed list for `## Business rules` (one rule per checkbox or bullet, numbered R-01, R-02, …) |
| `## Files to create/modify` / `## Implementation notes` | quoted under `## Implementation hints` (informational, NOT business rules) |
| `## References` / `## Links` | `## References` |
| `## Dependencies` | `## Dependencies` |

If a checkbox is purely technical scaffolding ("oxlint clean", "snapshots regenerated", "i18n parity test green") classify it as **non-business** and surface it under `## Non-business gates` — these become reviewer hints, not Gherkin rules.

### 4. Interview to fill the gaps

The pipeline needs five fields the issue rarely supplies; ask only for missing ones:

1. **Actor** — who triggers the behavior? Be specific (role, not "user").
2. **Action** — phrased as a verb against the actor's goal.
3. **User-story sentence** — `As a <actor>, I want to <action>, so that <goal>.`
4. **Concrete data** — pick representative values for any rule that mentions a threshold, list, or state. The pipeline rejects placeholders downstream; capture values now.
5. **Test-level hint** — likely `@ui` for frontend issues, `@e2e` for integration, `@use-case` for pure domain. Confirm.

Skip questions whose answer is unambiguous from the issue body.

### 5. Write `context.md`

Path: `<paths.specs>/<us-slug>/context.md` (from `.atdd-pipeline.json`).

Structure (same as [`impact-map`](../impact-map/SKILL.md), with two extra sections):

```markdown
# <us-slug>

## Source
GitHub issue #<N>: <title>
URL: <html_url>

## Actor
<role>

## Goal
<copied from ## Goal section if present, otherwise filled from interview>

## Action
<from interview if not derivable>

## User story
As a <actor>, I want to <action>, so that <goal>.

## Business rules
- R-01: <text from acceptance checkbox 1>
- R-02: <text from acceptance checkbox 2>
- ...

## Non-business gates
- <technical checkbox 1, e.g. "oxlint clean">
- ...

## Implementation hints
- <files to create/modify, if listed>
- <architecture references, e.g. "ARCHI.md §6.5">

## Dependencies
- <blocked by T-234>

## References
- <PRD.md F-003>
- ...

## Milestone
<from issue.milestone if any, else "TBD">

## Default test level
<@use-case | @e2e | @ui from interview>
```

### 6. Tag the issue

Apply ATDD labels in-place (does not duplicate the issue):

```bash
gh issue edit <N> --add-label "atdd,us/<us-slug>"
```

If the user confirmed a test level, also add `level/<use-case|e2e|ui>`.

Do NOT remove the project's existing labels (`scope:`, `track:`, `priority:`, `sprint:`, etc.). They coexist with ATDD labels.

### 7. Seed `issues.json`

If `<paths.specs>/<us-slug>/issues.json` does not exist, create it with the imported issue as the parent AND the US (no separate parent / US split — the imported issue already plays both roles):

```json
{
  "_imported_from": <N>,
  "parent": <N>,
  "us": <N>,
  "milestone": "<m>",
  "scenarios": {}
}
```

`to-issues-atdd` (re-)run later will populate `scenarios` after `spec-generate`. It will detect the `_imported_from` field and NOT create a new parent.

### 8. Handoff

Tell the user:

> Imported issue #<N> as `<us-slug>`. Next:
> - `/spec-generate` to turn the business rules into Gherkin scenarios.
> - Then `/spec-review`.
> - Then `/to-issues-atdd` will create scenario sub-issues linked to #<N>.

## Idempotency

If `<paths.specs>/<us-slug>/context.md` already exists:

- Show a diff between current content and what would be written.
- Ask: overwrite, merge (add only new rules), or abort.
- Never silently overwrite.

## Anti-patterns

- Do NOT promote technical checkboxes ("snapshots regenerated", "oxlint clean") to business rules. They are not behaviors the customer cares about; they are CI gates. They land under `## Non-business gates`.
- Do NOT close or re-title the imported issue. The team's history stays intact.
- Do NOT split an issue into multiple US during import. If the issue covers two unrelated stories, ask the user to file a second issue first.
