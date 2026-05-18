# Contributing

This plugin is pre-1.0. Skill names, frontmatter, and on-disk artifact paths can still change. If you want to contribute, that's the lens to keep in mind: clarity over backwards compatibility for now.

## Reporting bugs

Open an issue with the **Bug Report** template. Two things help most:

1. The exact slash command you ran and the args.
2. The state on disk after the failure (`specs/<us-slug>/` listing, `.atdd-pipeline.json`, any escalation file).

If the bug involves `pr-auto-merge`, attach `specs/<us-slug>/.cycles/<n>/auto-merge.log`. That's where the CI/bot watch timeline lives.

## Suggesting changes

Open a **Feature Request**. Lead with the problem, not the solution. If you already have a fix in mind, sketch it at the end so the design discussion stays open.

Before opening anything, search [existing issues](https://github.com/mpiton/agentic-atdd/issues?q=is%3Aissue) — the pre-1.0 list moves fast.

## Pull requests

Workflow:

1. Fork, branch off `main`. Use `feat/...`, `fix/...`, `docs/...`, `refactor/...` as a prefix.
2. Change one skill (or one concern) per PR. Smaller is easier to merge.
3. If you touch a reviewer skill (`review-fidelity`, `review-architecture`, `review-intent`), add or update a fixture in `tests/fixtures/` and link to the regression case in the PR body.
4. Commit using [Conventional Commits](https://www.conventionalcommits.org). The `chore:` / `feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `perf:` / `ci:` set is enough.
5. Open the PR. Fill in the template. CI runs the fixtures.

If the PR adds a new skill, update three places:

- `README.md` — the skill table.
- `.claude-plugin/plugin.json` — `skills` and `commands`.
- `docs/USAGE.md` — only if the skill changes a user-facing flow.

Anything else is plumbing and lives in the SKILL.md itself.

## Local setup

```bash
git clone https://github.com/mpiton/agentic-atdd.git
cd agentic-atdd
```

The plugin has no runtime install. To test it against a real project:

```bash
# Symlink into both harnesses (Claude Code + Codex)
./scripts/install.sh
```

The script symlinks every skill folder into `~/.claude/skills/` and `~/.codex/skills/`, so a local edit to `SKILL.md` propagates immediately. Restart your CLI to refresh the skill index.

## Testing reviewer prompts

Reviewer skills are prompts. Their regressions are hard to catch without fixtures. The contract:

```
tests/fixtures/<reviewer>/<case>/
  ├── scenario.feature          # input
  ├── test.ts (or diff.patch)   # input
  ├── context.md                # optional
  └── expected.md               # ground-truth verdict (OK | REGENERATE) + reasons
```

`tests/README.md` documents how to replay them. If you change a reviewer prompt, run the existing fixtures and add a new one for whatever case motivated the change.

## Code of conduct

Be civil, be specific, be brief. If you wouldn't say it in a code review out loud, don't write it in a comment.

## Questions

Open a [Discussion](https://github.com/mpiton/agentic-atdd/discussions) for usage questions, design conversations, or "is this the right tool for X" before filing an issue.
