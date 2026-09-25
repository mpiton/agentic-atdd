# orchestrate/

End-to-end drivers that chain skills from the other buckets.

- **[atdd-run](atdd-run/SKILL.md)** — Full pipeline: impact-map → spec-generate → spec-review → human checkpoint #1 → to-issues-atdd → (per scenario: red-cycle → green-cycle in the scenario subagent, then pr-auto-merge in the merge subagent) → verify-acceptance (once, on the integration tip) → final PR → human checkpoint #2.
- **[setup-atdd-pipeline](setup-atdd-pipeline/SKILL.md)** — First-run per-repo configuration. Writes `.atdd-pipeline.json` at the repo root.
