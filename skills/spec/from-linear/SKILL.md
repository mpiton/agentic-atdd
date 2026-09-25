---
name: from-linear
description: Import a Linear ticket into the ATDD pipeline. Fetches the card via Linear MCP, CLI, or GraphQL API (first one available), parses the description into a context.md, interviews the user to fill gaps, and hands off to spec-generate. Use when the story lives in Linear (ticket like ENG-123).
phase: 1-input
parallel: false
inputs: [linear-ticket-id]
outputs: [context-md]
escalation: none
---

# /from-linear <ticket-id>

Entry point for teams whose stories live in Linear. The card stays in Linear; this skill back-fills the structured artifacts the pipeline needs, then the normal chain takes over. GitHub Issues remains the pipeline's database — `to-issues-atdd` will create the parent / US / sub-issues fresh, and the Linear reference travels in `context.md`.

## When to use

- The team tracks work in Linear and the card already carries the goal and acceptance criteria.
- You want to drive that card through `spec-generate` → `red-cycle` / `green-cycle` without retyping it.

Even if the card's description already contains Gherkin, you still go through this skill — unlike a GitHub issue, a Linear card has no sub-issue for `/red` to target yet. `spec-generate` may then reuse the existing scenarios verbatim instead of inventing new ones.

## Inputs

- `<ticket-id>` — Linear issue identifier, e.g. `ENG-123`. Accept it case-insensitive and with or without a URL around it (`https://linear.app/<org>/issue/ENG-123/...` → `ENG-123`).

## Workflow

### 1. Resolve an access path

Probe in order. Use the first that works; tell the user which one you picked.

1. **MCP** — Linear MCP tools available in the session (tool names like `get_issue`, `list_comments` from a `linear` server). Preferred on Claude Code: structured fields, no parsing.
2. **CLI** — a `linear` binary on PATH (`command -v linear`). Community CLIs vary; read `linear --help` first and use its issue-view command. Do not guess flags.
3. **GraphQL API** — `LINEAR_API_KEY` set in the environment (personal API key, Linear → Settings → API). `issue(id:)` accepts the human identifier, not just the UUID:

```bash
curl -s https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  --data '{
    "query": "query Issue($id: String!) { issue(id: $id) { identifier title description url state { name } labels { nodes { name } } project { name } projectMilestone { name } comments { nodes { body createdAt user { displayName } } } } }",
    "variables": { "id": "<ticket-id>" }
  }'
```

If none of the three works, stop and tell the user the options: enable the Linear MCP server, install a Linear CLI, or `export LINEAR_API_KEY=...`. Do NOT reconstruct the card from memory or from the user's prose — the card content is the input.

### 2. Fetch the ticket

Pull at minimum: identifier, title, description (markdown), URL, state, labels, project, milestone. Also fetch comments — acceptance criteria and clarifications often live there. Quote anything you take from a comment with its author.

### 3. Derive the slug

Build the `us-slug` from the identifier plus the title, kebab-cased and trimmed to 6 significant words: `ENG-123: Checkout du panier` → `eng-123-checkout-du-panier`.

Present the proposed slug to the user; accept an override.

### 4. Parse known sections

Same mapping as [`from-issue`](../from-issue/SKILL.md). Look for these headings in the description (and in comments). Use what you find; do NOT invent content.

| Heading found | Maps to |
|---|---|
| `## Goal` / `## Description` / `## Context` | `## Goal` in `context.md` |
| `## Acceptance criteria` / `## Acceptance` / `## Definition of done` | seed list for `## Business rules` (one rule per checkbox or bullet, numbered R-01, R-02, …) |
| `## Files to create/modify` / `## Implementation notes` | quoted under `## Implementation hints` (informational, NOT business rules) |
| `## References` / `## Links` | `## References` |
| `## Dependencies` | `## Dependencies` |

If a checkbox is purely technical scaffolding ("oxlint clean", "snapshots regenerated") classify it as **non-business** and surface it under `## Non-business gates` — these become reviewer hints, not Gherkin rules.

### 5. Interview to fill the gaps

The pipeline needs five fields the card rarely supplies; ask only for missing ones:

1. **Actor** — who triggers the behavior? Be specific (role, not "user").
2. **Action** — phrased as a verb against the actor's goal.
3. **User-story sentence** — `As a <actor>, I want to <action>, so that <goal>.`
4. **Concrete data** — pick representative values for any rule that mentions a threshold, list, or state. The pipeline rejects placeholders downstream; capture values now.
5. **Test-level hint** — likely `@ui` for frontend cards, `@e2e` for integration, `@use-case` for pure domain. Confirm.

Skip questions whose answer is unambiguous from the card.

### 6. Write `context.md`

Path: `<paths.specs>/<us-slug>/context.md` (from `.atdd-pipeline.json`).

Same structure as [`from-issue`](../from-issue/SKILL.md), with the Linear card as source:

```markdown
# <us-slug>

## Source
Linear <identifier>: <title>
URL: <linear url>

## Actor
<role>

## Goal
<from the card if present, otherwise filled from interview>

## Action
<from interview if not derivable>

## User story
As a <actor>, I want to <action>, so that <goal>.

## Business rules
- R-01: <text from acceptance bullet 1>
- ...

## Non-business gates
- <technical checkbox, e.g. "oxlint clean">

## Implementation hints
- <files to create/modify, if listed>

## Dependencies
- <blocked by ENG-122>

## References
- <linked docs, PRD sections>

## Milestone
<from project milestone if any, else "TBD">

## Default test level
<@use-case | @e2e | @ui from interview>
```

### 7. Back-link Linear (best effort)

If the access path allows writes, post one comment on the card:

> Imported into the ATDD pipeline as `<us-slug>` in `<owner>/<repo>`. Scenario sub-issues will land on GitHub.

Optionally add an `atdd` label if label operations are available. If the access path is read-only (API key without write scope, read-only MCP), skip silently — never fail the import on the back-link. Do not change the card's state, title, or assignee.

### 8. Handoff

Unlike `from-issue`, do NOT seed `issues.json` — there is no GitHub issue to reuse as parent/US. `to-issues-atdd` will create the full hierarchy after `spec-generate`.

Tell the user:

> Imported Linear <identifier> as `<us-slug>`. Next:
> - `/spec-generate` to turn the business rules into Gherkin scenarios.
> - Then `/spec-review`.
> - Then `/to-issues-atdd` will create the GitHub parent, US, and scenario sub-issues.
> - Or `/atdd-run <us-slug>` to chain everything.

## Idempotency

If `<paths.specs>/<us-slug>/context.md` already exists:

- Show a diff between current content and what would be written.
- Ask: overwrite, merge (add only new rules), or abort.
- Never silently overwrite.

Re-running must not post a second back-link comment — check the card's comments for the import marker first.

## Anti-patterns

- Do NOT promote technical checkboxes to business rules. They land under `## Non-business gates`.
- Do NOT copy the whole card description into a GitHub issue body — `to-issues-atdd` builds the hierarchy from `context.md`, not from a mirror of the card.
- Do NOT close, re-title, or move the Linear card. The team's board stays theirs; the pipeline only reads it and leaves one comment.
- Do NOT fall back to interviewing the card content out of the user when no access path works. Fix the access path; the card is the source of truth.
