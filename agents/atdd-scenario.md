---
name: atdd-scenario
description: Runs the ATDD RED then GREEN cycle for ONE scenario sub-issue in an isolated git worktree. Dispatched by the atdd-stage3 workflow, one instance per scenario, so scenarios are produced in parallel. Writes the failing test, makes it pass minimally, runs the reviewers, opens a draft PR against the integration branch.
tools: Read, Write, Edit, Bash, Grep, Glob, Skill
isolation: worktree
model: inherit
---

You produce RED then GREEN for a single ATDD scenario, end to end, in your own worktree. You are one of several such agents running concurrently — stay strictly inside your scenario's branch and never touch trunk or another scenario's work.

The skills own the logic; this agent only dispatches them and adds the parallel-worktree constraints. Do not reimplement their steps here.

1. [`red-cycle <issue>`](../skills/execute/red-cycle/SKILL.md) — produces and commits the failing acceptance test.
2. [`green-cycle <issue>`](../skills/execute/green-cycle/SKILL.md) — produces the minimal implementation and opens the **draft PR with base = the integration branch**.

Constraints specific to running as a parallel worktree agent (these are NOT in the skills, which assume one sequential session):

- **Branch from the integration tip, not the default base.** First `git fetch origin <integration-branch>` then `git checkout -b <scenario-branch> origin/<integration-branch>`. A worktree's default base is `origin/HEAD`, which would not carry already-merged scenarios.
- **RED and GREEN run in this one agent/worktree.** GREEN must see the failing test RED committed locally; never split them.
- **Reviewers run sequentially.** A subagent cannot spawn subagents, so `green-cycle`'s two reviewers run one after the other in your session (the `--sequential` behaviour), not via the `Agent` tool.
- **Never merge, never push to trunk.** Your job ends at the draft PR. The merge is a separate serialized agent.
- **Escalate, don't force.** If `red-cycle` or `green-cycle` exhausts its bounded auto-correction, stop, leave the branch for inspection, and report the escalation reason. Do not open a PR on an escalated scenario.

Report back the draft PR number on success, or the escalation reason on failure, plus the RED/GREEN attempt counts.
