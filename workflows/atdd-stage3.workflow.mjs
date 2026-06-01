// atdd-stage3.workflow.mjs
//
// Stage 3 of the ATDD pipeline as a dynamic-workflow script: produce RED+GREEN for
// every scenario concurrently in isolated git worktrees, then merge each sub-PR into the
// integration branch through a single serialized lane. This is the OPT-IN, experimental
// parallel path. The sequential loop in atdd-run/SKILL.md remains the default and the
// only path under Codex; this script is launched by the model running atdd-run via the
// Workflow tool (scriptPath = ${CLAUDE_PLUGIN_ROOT}/workflows/atdd-stage3.workflow.mjs)
// only when stage3_mode == "workflow" AND the Workflow tool is available.
//
// Why a workflow and not the model looping: the per-scenario RED+GREEN work is fully
// independent (each writes its own scenario branch); only the merge into the shared
// integration branch is contended. Today's atdd-run serializes the WHOLE cycle to avoid
// racing the merge queue. This script serializes ONLY the merge, so the expensive 80%
// (write test, write impl, review, fix) runs in parallel.
//
// HARD invariants (do not weaken — they are why the parallel path is safe):
//   1. RED and GREEN for one scenario run in the SAME worktree/agent, because GREEN must
//      see RED's locally-committed failing test. They are never split across agents.
//   2. Each scenario branch is cut explicitly from origin/<integrationBranch> INSIDE the
//      worktree (git fetch + checkout -b), NOT from the worktree's default base. Relying
//      on worktree baseRef defaults (origin/HEAD) is the documented footgun.
//   3. The merge stage is serialized via a single lane. Each merge rebases its branch onto
//      the CURRENT integration tip (other scenarios may have merged since it was cut) and
//      re-runs CI before merging. A real rebase conflict escalates; it never force-merges.
//   4. Nothing here merges into trunk. The trunk-merge guard hook is the deterministic
//      backstop; a merge whose base resolves to trunk is a bug, not an expected path.
//
// Human gates live OUTSIDE this script: spec checkpoint #1 runs before atdd-run launches
// it, and the final integration->trunk PR (checkpoint #2) is opened after it returns.
// Dynamic workflows take no mid-run human input, so no gate may live inside.
//
// Expected `args` (passed by atdd-run):
//   {
//     usSlug: string,
//     integrationBranch: string,           // e.g. "atdd/cart-checkout/integration"
//     specsDir: string,                     // e.g. "specs/cart-checkout"
//     conventions: string,                  // optional: pre-extracted shared language +
//                                           //   relevant ADRs, handed to each scenario
//                                           //   agent so N agents don't each re-discover
//                                           //   the same conventions (token cache)
//     scenarios: [                          // from issues.json.scenarios, flattened
//       { slug, issue, branch, level, rule, feature }
//     ]
//   }
// Returns { merged: [slug], escalated: [{slug, issue, pr, reason}] } so atdd-run can write
// run-state.json and gate Stage 4.

export const meta = {
  name: 'atdd-stage3',
  description: 'ATDD Stage 3: per-scenario RED+GREEN in isolated worktrees, then a serialized rebase+CI+auto-merge lane into the integration branch. Opt-in parallel path; sequential stays the default.',
  phases: [
    { title: 'Produce', detail: 'RED+GREEN per scenario in an isolated worktree (parallel)' },
    { title: 'Merge', detail: 'serialized rebase + CI watch + auto-merge into integration' },
  ],
}

const usSlug = args && args.usSlug
const integrationBranch = args && args.integrationBranch
const specsDir = (args && args.specsDir) || `specs/${usSlug}`
const conventions = (args && args.conventions) || ''
const scenarios = (args && args.scenarios) || []

if (!usSlug || !integrationBranch || scenarios.length === 0) {
  log('atdd-stage3: missing usSlug / integrationBranch / scenarios in args — nothing to do.')
  return { merged: [], escalated: [] }
}

// Result of the produce (RED+GREEN) stage for one scenario.
const PRODUCE_SCHEMA = {
  type: 'object',
  required: ['slug', 'issue', 'escalated'],
  properties: {
    slug: { type: 'string' },
    issue: { type: 'number' },
    branch: { type: 'string' },
    pr: { type: 'number', description: 'draft PR number when GREEN succeeded; omit on escalation' },
    escalated: { type: 'boolean' },
    reason: { type: 'string', description: 'escalation reason when escalated=true' },
    red_attempts: { type: 'number' },
    green_attempts: { type: 'number' },
  },
}

// Result of the serialized merge stage for one scenario.
const MERGE_SCHEMA = {
  type: 'object',
  required: ['slug', 'issue', 'merged'],
  properties: {
    slug: { type: 'string' },
    issue: { type: 'number' },
    pr: { type: 'number' },
    merged: { type: 'boolean' },
    escalated: { type: 'boolean' },
    reason: { type: 'string' },
    fix_iterations: { type: 'number' },
  },
}

// Single serialized merge lane: only one merge agent touches the integration branch at a
// time. Each enqueued merge waits for the previous to settle, so rebases happen in order
// against the real, advancing integration tip. The lane never rejects (errors are folded
// to the per-item result), so one failed merge does not poison the chain.
let mergeLane = Promise.resolve()
function enqueueMerge(thunk) {
  const run = mergeLane.then(thunk, thunk)
  mergeLane = run.then(() => {}, () => {})
  return run
}

phase('Produce')

const results = await pipeline(
  scenarios,

  // Stage A — RED + GREEN together, isolated. Parallel across scenarios (no barrier).
  (s) => agent(
    [
      `Execute ATDD RED then GREEN for scenario #${s.issue} ("${s.slug}", rule ${s.rule || '?'}, level ${s.level || '?'}) of user story "${usSlug}".`,
      ``,
      `Setup (do this first, inside your worktree):`,
      `- git fetch origin ${integrationBranch}`,
      `- git checkout -b ${s.branch} origin/${integrationBranch}   # branch from the integration TIP, not origin/HEAD`,
      ``,
      `1. Run the red-cycle skill for issue ${s.issue}: write ONE failing acceptance test that mirrors the Gherkin in the issue, run review-fidelity, auto-correct at most twice. Commit the failing test on ${s.branch}.`,
      `2. Run the green-cycle skill for issue ${s.issue}: write the minimal implementation, run review-architecture and review-intent, auto-correct at most twice. Open a DRAFT PR with base ${integrationBranch} (NEVER trunk).`,
      ``,
      conventions ? `Project conventions (shared language + relevant ADRs), pre-extracted so you don't re-discover what every scenario shares — still consult any ADR your own diff specifically touches:\n<conventions>\n${conventions}\n</conventions>` : '',
      `RED and GREEN MUST happen in THIS worktree so GREEN sees RED's committed failing test. Do not push to or merge into trunk.`,
      `If red-cycle or green-cycle exhausts its auto-correction, STOP: leave the branch, set escalated=true with the reason, omit pr. Otherwise return the draft PR number.`,
      `Write the reviewer reports under ${specsDir}/.cycles/${s.issue}/ as the skills specify.`,
    ].join('\n'),
    { label: `produce:${s.slug}`, phase: 'Produce', schema: PRODUCE_SCHEMA, isolation: 'worktree', agentType: 'atdd-scenario' },
  ),

  // Stage B — serialized merge. Returns the produce result untouched on escalation.
  (produced, s) => {
    if (!produced) {
      return { slug: s.slug, issue: s.issue, merged: false, escalated: true, reason: 'produce stage returned no result' }
    }
    if (produced.escalated || !produced.pr) {
      return { slug: s.slug, issue: s.issue, pr: produced.pr, merged: false, escalated: true, reason: produced.reason || 'green-cycle did not open a PR' }
    }
    return enqueueMerge(() => agent(
      [
        `Serialized merge of scenario #${s.issue} ("${s.slug}"), draft PR #${produced.pr}, into ${integrationBranch}.`,
        `You hold the single merge lane — no other merge runs concurrently.`,
        ``,
        `1. Rebase the PR branch (${produced.branch || s.branch}) onto the CURRENT tip of origin/${integrationBranch}; earlier scenarios may have merged since this branch was cut.`,
        `   - On a clean rebase: force-push the rebased branch and continue.`,
        `   - On a REAL conflict you cannot resolve mechanically: do NOT guess. Set merged=false, escalated=true, reason="rebase conflict", and return. Leave the PR open.`,
        `2. Run the pr-auto-merge skill for PR #${produced.pr}: mark ready, watch CI (it re-runs after the rebase), watch bot idle, run apply-pr-feedback on actionable feedback (bounded by max_fix_iterations), then squash-merge into ${integrationBranch}.`,
        ``,
        `The trunk-merge guard hook blocks any merge whose base is trunk; that must never fire here (base is ${integrationBranch}). Report merged true/false, the pr number, and fix_iterations used.`,
      ].join('\n'),
      { label: `merge:${s.slug}`, phase: 'Merge', schema: MERGE_SCHEMA, agentType: 'atdd-merge' },
    ))
  },
)

const settled = results.filter(Boolean)
const merged = settled.filter((r) => r.merged)
const escalated = settled.filter((r) => !r.merged)

log(`Stage 3 complete: ${merged.length} merged, ${escalated.length} escalated/incomplete of ${scenarios.length} scenarios.`)

const spent = (typeof budget !== 'undefined' && budget && budget.spent) ? budget.spent() : null
if (spent != null) {
  log(`Stage 3 token spend: ~${Math.round(spent / 1000)}k output tokens across ${scenarios.length} scenarios.`)
}

return {
  merged: merged.map((r) => r.slug),
  escalated: escalated.map((r) => ({ slug: r.slug, issue: r.issue, pr: r.pr || null, reason: r.reason || 'incomplete' })),
}
