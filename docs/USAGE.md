# Using agentic-atdd on a real project

Three entry paths, depending on what you already have in your hand. Pick the one that matches your situation.

## Before anything

You need:

- `gh` CLI authenticated against the target repo (`gh auth status`).
- The plugin symlinked into your skill folder (run `~/.claude/plugins/atdd-pipeline/scripts/install.sh` once).
- A clean working tree on `main` (the pipeline creates branches off it).

Then, once per repo:

```bash
/setup-atdd-pipeline
```

This is an interview. It asks for the tracker (`github` or `local`), the spec base path, the test conventions per level, the trunk branch (default `main`), the integration branch pattern, and the auto-merge knobs. The answers land in `.atdd-pipeline.json` at the repo root. Commit that file.

If you change your mind later, rerun `/setup-atdd-pipeline` — it reads the current config and only asks about fields you want to change.

---

## Case A — you have a GitHub issue already

Your team uses GitHub Issues. The issue is written (sometimes Gherkin, sometimes prose), you don't want to recreate it. Concrete example: [`mpiton/forgent#130`](https://github.com/mpiton/forgent/issues/130).

```bash
/from-issue 130
```

This:

1. Fetches the issue via `gh issue view`.
2. Parses what it can from the body (goal, acceptance criteria).
3. Asks you to fill the gaps (rules that weren't explicit, ambiguous numbers, missing edge cases).
4. Writes `specs/<us-slug>/context.md`.
5. Tags the issue with `atdd`, `us/<us-slug>`, level/rule labels.

You stay on the same issue — no duplicate gets created.

Next:

```bash
/spec-generate
/spec-review
```

`spec-generate` interviews you on whatever is still ambiguous and writes one `.feature` file per business rule. `spec-review` audits them and writes `review.md` with a verdict.

Read the verdict. If it says `REGENERATE`, look at the reasons, run `/spec-generate` again with the additional context. If it says `OK`, you continue:

```bash
/to-issues-atdd
```

This creates a parent issue (`[Goal] …`), a user story issue (`[US] <slug>`), and one sub-issue per scenario. It also pushes a fresh integration branch `atdd/<slug>/integration` off `main`. The mapping lives at `specs/<us-slug>/issues.json`.

Now per scenario (or use `/atdd-run` to chain everything below):

```bash
/red <sub-issue>
/green <sub-issue>
/auto-merge <pr>      # if you're driving manually
```

`/auto-merge` watches the draft PR through CI and bot review, runs `fix-pr-comments` if bots flag anything, and squash-merges into the integration branch when it's clean. It refuses to merge anything whose base is `main`.

When every scenario is in, the orchestrator opens the final PR from the integration branch to `main` and stops. That PR is the one you review and merge yourself.

If you want the whole chain after `from-issue`:

```bash
/atdd-run <us-slug>
```

Same result, fewer keystrokes. The orchestrator stops at the two human gates.

---

## Case B — fresh feature, PRD and architecture in hand

You have a PRD, you have ADRs, the shared language is already written down. You just want to break a story into scenarios and ship it.

```bash
/impact-map
```

Interview to capture the story, the actor, the goal, the business rules. The skill reads your `PRD.md` and `docs/adr/` as references so it doesn't ask you things you've already documented. Output: `specs/<us-slug>/context.md`.

From here it's identical to Case A:

```bash
/spec-generate
/spec-review
# checkpoint #1 — you say OK
/to-issues-atdd
# scenarios get issues + integration branch is created
/atdd-run <us-slug> --from-stage red
# or run /red, /green, /auto-merge per sub-issue
```

Between scenarios, if patterns emerge (recurring shape across three or four implementations), drop in `improve-codebase-architecture` from mattpocock's skill pack to refactor and update an ADR. Run it between cycles, never inside one — it would invalidate the minimal-diff invariant `green-cycle` enforces.

---

## Case C — greenfield, nothing written down yet

New project, no PRD, no ADRs, no shared language file. You start by bootstrapping context.

```bash
/setup-atdd-pipeline
# tracker can be `local` if you don't have a GitHub repo yet
```

Then:

```bash
# from mattpocock's skills — grills you on the domain and writes CONTEXT.md + first ADRs
grill-with-docs
```

This gives you a shared language file and a few foundational architecture decisions. Optionally:

```bash
to-prd   # mattpocock — formal PRD if you want one before scenarios
```

Now you have enough context to enter the normal flow:

```bash
/impact-map
/spec-generate
/spec-review
# checkpoint #1
/to-issues-atdd
/atdd-run <us-slug> --from-stage red
```

In greenfield, expect `spec-generate` to interview you heavily — there's no PRD to lean on, so it asks more. That's fine, that's the point. Revisit `CONTEXT.md` often during the first two or three scenarios. Patterns surface fast.

---

## Resuming a run

`atdd-run` is idempotent. If you got interrupted mid-flight (Claude Code crashed, bot timeout, you killed the terminal), the skill reads its own artifacts on disk and figures out where to pick up. To force a specific resume point:

```bash
/atdd-run <us-slug> --from-stage spec        # rerun spec-generate + spec-review
/atdd-run <us-slug> --from-stage sync        # rerun to-issues-atdd (idempotent, safe)
/atdd-run <us-slug> --from-stage red         # next scenario's red cycle
/atdd-run <us-slug> --from-stage auto-merge  # take over PRs already opened
/atdd-run <us-slug> --from-stage final-pr    # just open the integration → main PR
```

`--dry-run` prints what would happen without writing anything. Useful when you want to see the issue plan before letting the pipeline create real tickets.

`--sequential` forces the reviewers to run one after the other instead of in parallel. Use it under Codex (no `Task` tool) or when you're rate-limited.

`--no-auto-merge` puts you back in the old flow: a manual `MERGE` / `CHANGE` / `SKIP` prompt after every `green-cycle`. Keep that flag in mind if your project has a CI you don't trust yet — better to gate each scenario PR by hand than to let the pipeline ship something broken.

---

## When auto-merge gives up

`pr-auto-merge` escalates in three cases:

1. CI keeps failing after the fix-pr-comments cap (default 3 iterations).
2. The bot idle window never closes within `watch_timeout_minutes` (default 60).
3. A reviewer has a `CHANGES_REQUESTED` review that `fix-pr-comments` couldn't address.

When it gives up, it posts a comment on the PR with the timeline and leaves the PR open. The orchestrator records the PR number in `specs/<us-slug>/escalations.md` and moves on to the next scenario. Read the escalation, fix it by hand, then trigger `/auto-merge <pr>` again — it resumes from where it stopped.

---

## When the spec review keeps saying REGENERATE

The most common cause is that you haven't given the pipeline enough concrete data. "User can checkout" is not a scenario. "User checks out a cart with one item priced 12.50 EUR, shipping is 4.99 EUR, total should be 17.49 EUR" is. If `spec-review` is unhappy, look at its `Triangulation` axis first — that's the one that catches abstract scenarios pretending to be concrete.

If you're stuck, drop the verdict reasons into `/impact-map` as additional rules and rerun `/spec-generate`. The interview will surface what you missed.

---

## What lives on disk versus in GitHub

GitHub Issues is the database. The breakdown, the labels, the escalation comments, the merge state — all of it is on GitHub. You can rerun the pipeline against a fresh clone and it picks up the world from there.

The repo holds:

- `specs/<us-slug>/context.md` — the captured story.
- `specs/<us-slug>/*.feature` — one Gherkin file per business rule.
- `specs/<us-slug>/review.md` — the verdict from `spec-review`.
- `specs/<us-slug>/issues.json` — the mapping from scenario slug to issue number, plus the integration branch name.
- `specs/<us-slug>/.cycles/<n>/*.md` — per-scenario reviewer reports.
- `specs/<us-slug>/.cycles/<n>/auto-merge.log` — the CI + bot watch timeline.
- `specs/<us-slug>/escalations.md` — only present if at least one cycle escalated.

You commit all of it. The pipeline reads these files when you resume.

---

## Codex vs Claude Code

The same `SKILL.md` files work on both harnesses. Two behavioural differences:

- Parallel reviewers run via the `Task` tool on Claude Code. Under Codex, there's no `Task` tool, so the orchestrator runs the reviewers sequentially in the same session. You can force this anywhere with `--sequential`.
- Subagent dispatch under Claude Code uses the `Agent` tool when available; under Codex, the orchestrator inlines the equivalent prompt.

Everything else is identical. The plugin lives in one folder, symlinked to both `~/.claude/skills/` and `~/.codex/skills/`.

---

## Troubleshooting

**A skill doesn't show up after I edit it.** Restart your CLI. Skills are indexed at session start.

**`pr-auto-merge` won't merge my sub-PR even though CI is green.** Check the base branch with `gh pr view <pr> --json baseRefName`. If it's `main` instead of `atdd/<slug>/integration`, `green-cycle` opened it against the wrong base — usually because the integration branch didn't exist yet. Run `/to-issues-atdd` to provision it, then `gh pr edit <pr> --base atdd/<slug>/integration` to retarget.

**Bot review never finishes.** Tune `auto_merge.idle_window_minutes` down (default 5) and `auto_merge.watch_timeout_minutes` (default 60). If a bot you rely on isn't being detected, add its login to `auto_merge.bot_logins` — the default allowlist covers `coderabbitai`, `coderabbitai[bot]`, `github-actions[bot]`, `codex`, `codex-bot`. Anything beyond that needs to be listed explicitly or have `user.type == "Bot"` in the GitHub API.

**`spec-generate` writes scenarios that mock the system under test.** That's a bug in the level label. Check the issue's `level/<x>` label — if it's set to `use-case` but the scenario implies an HTTP call, the test driver is fighting the level. Either change the level (`gh issue edit <n> --add-label level/e2e --remove-label level/use-case`) or rewrite the scenario to stay in the domain.

**The integration branch diverged from main while I was running scenarios.** Rebase manually: `git checkout atdd/<slug>/integration && git rebase main`. The pipeline doesn't do this automatically because it's a destructive operation and you should look at the conflicts yourself.

---

## Visual reference

A side-by-side diagram of the three cases lives at [`workflows.html`](workflows.html). Open it in a browser — three columns (Case A, B, C), each one a vertical chain of slash commands with the phase color, the output path, and the two human gates marked. Quicker than reading this whole document if you just need to remember the sequence.
