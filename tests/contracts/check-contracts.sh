#!/usr/bin/env bash
# Cross-skill contract checks for the atdd-pipeline plugin.
#
# The pipeline's control flow is encoded in exact strings spread across many SKILL.md
# files: reviewer VERDICT lines that consumers grep, the CodeRabbit marker pr-auto-merge
# keys on, the apply-pr-feedback return keys, the trunk-merge refusal, the escalation
# phrases. A wording change in a producer that a consumer still greps for silently breaks
# a gate. The reviewer fixtures under tests/fixtures/ catch a single skill drifting; these
# checks catch two skills falling out of agreement with each other.
#
# Pure grep over the repo — no Claude-only primitive, runs under any shell/CI. Exits 0 when
# every contract holds, 1 on the first batch of failures (all are reported, not just the
# first).
#
# Usage:  tests/contracts/check-contracts.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || {
  printf 'check-contracts: failed to cd into repo root: %s\n' "$ROOT" >&2
  exit 1
}

pass=0
fail=0

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }

# has FILE PATTERN — fixed-string grep, returns 0 if present.
has() { grep -qF -- "$2" "$1" 2>/dev/null; }
# hasE FILE PATTERN — extended-regex grep.
hasE() { grep -qE -- "$2" "$1" 2>/dev/null; }

ok()   { pass=$((pass+1)); printf '  %s %s\n' "$(green PASS)" "$1"; }
ko()   { fail=$((fail+1)); printf '  %s %s\n' "$(red FAIL)" "$1"; }

# contract DESC : runs the check passed as remaining args via a subshell test
# Convenience wrappers below keep each assertion one line.

assert_has() { # FILE PATTERN DESC
  if has "$1" "$2"; then ok "$3"; else ko "$3 — '$2' missing from ${1#$ROOT/}"; fi
}
assert_hasE() { # FILE REGEX DESC
  if hasE "$1" "$2"; then ok "$3"; else ko "$3 — /$2/ missing from ${1#$ROOT/}"; fi
}
assert_file() { # FILE DESC
  if [ -f "$1" ]; then ok "$2"; else ko "$2 — file ${1#$ROOT/} missing"; fi
}

S="skills"
FID="$S/execute/review-fidelity/SKILL.md"
ARC="$S/execute/review-architecture/SKILL.md"
INT="$S/execute/review-intent/SKILL.md"
SREV="$S/spec/spec-review/SKILL.md"
RED="$S/execute/red-cycle/SKILL.md"
GREEN="$S/execute/green-cycle/SKILL.md"
PAM="$S/execute/pr-auto-merge/SKILL.md"
APF="$S/execute/apply-pr-feedback/SKILL.md"
SYNC="$S/sync/to-issues-atdd/SKILL.md"
RUN="$S/orchestrate/atdd-run/SKILL.md"
GUARD="hooks/guard-merge.sh"

echo "atdd-pipeline cross-skill contracts"
echo

echo "[1] Reviewer VERDICT contract — producers emit exactly what consumers grep"
for f in "$FID" "$ARC" "$INT" "$SREV"; do
  assert_has "$f" "VERDICT: OK"         "$(basename "$(dirname "$f")") emits 'VERDICT: OK'"
  assert_has "$f" "VERDICT: REGENERATE" "$(basename "$(dirname "$f")") emits 'VERDICT: REGENERATE'"
done
assert_hasE "$RED"   "OK or REGENERATE|verdict .?OK" "red-cycle consumes a verdict"
assert_has  "$GREEN" "VERDICT"                       "green-cycle consumes VERDICT"
echo

echo "[2] apply-pr-feedback return contract — same keys on both sides"
for k in pushed_commit actionable_remaining all_out_of_scope replies_posted; do
  assert_has "$APF" "$k" "apply-pr-feedback declares '$k'"
done
assert_has "$PAM" "actionable_remaining" "pr-auto-merge branches on 'actionable_remaining'"
echo

echo "[3] CodeRabbit actionable marker — sentinel (change is intentional, not silent)"
assert_has "$PAM" "Actionable comments posted" "pr-auto-merge keys on CodeRabbit marker"
echo

echo "[4] Trunk-merge guard — hook covers what the prose promises"
assert_file "$GUARD"                              "guard-merge.sh shipped"
assert_has  "$GUARD" "gh pr merge"                "guard inspects 'gh pr merge'"
assert_has  "$GUARD" "baseRefName"                "guard resolves PR base"
assert_hasE "$PAM"   "base.*(trunk|main)|trunk"   "pr-auto-merge documents the trunk refusal"
echo

echo "[5] RED/GREEN precondition agreement — exactly one failing test"
assert_hasE "$RED"   "ONE failing|failing (acceptance )?test" "red-cycle produces one failing test"
assert_hasE "$GREEN" "one failing test|failing test exists"   "green-cycle preconditions on the failing test"
echo

echo "[6] Integration-branch contract — never target trunk"
assert_has  "$SYNC"  "integration_branch"           "to-issues-atdd emits integration_branch"
assert_has  "$GREEN" "integration_branch"           "green-cycle targets integration_branch"
assert_hasE "$GREEN" "NEVER .?trunk|never .?trunk_branch|never \`trunk" "green-cycle forbids trunk base"
echo

echo "[7] Escalation contract — escalating skills emit ESCALATED:, orchestrator records it"
assert_has "$RED"   "ESCALATED:" "red-cycle escalation phrase"
assert_has "$GREEN" "ESCALATED:" "green-cycle escalation phrase"
assert_has "$PAM"   "ESCALATED:" "pr-auto-merge escalation phrase"
assert_has "$RUN"   "escalations.md" "atdd-run records escalations.md"
assert_has  "$RUN"  "PushNotification" "atdd-run emits a best-effort escalation push"
assert_hasE "$RUN"  "status: \"escalated\"|status.*escalated" "atdd-run marks run-state status escalated"
echo

echo "[8] Run-state contract — orchestrator owns a resumable, reconciled state file"
assert_has  "$RUN" "run-state.json"                 "atdd-run defines run-state.json"
assert_hasE "$RUN" "merged.*escalated.*unmerged|unmerged" "Stage 4 classifies scenario status"
assert_hasE "$RUN" "[Rr]econcile" "atdd-run reconciles state against GitHub on resume"
echo

echo "[9] Stage 3 workflow substrate — shipped artifacts agree with the dispatcher"
WF="workflows/atdd-stage3.workflow.mjs"
AG_SCN="agents/atdd-scenario.md"
AG_MRG="agents/atdd-merge.md"
assert_file "$WF"      "atdd-stage3 workflow shipped"
assert_has  "$WF" "export const meta"        "workflow has a meta block"
assert_has  "$WF" "agentType: 'atdd-scenario'" "workflow dispatches the atdd-scenario agent"
assert_has  "$WF" "agentType: 'atdd-merge'"    "workflow dispatches the atdd-merge agent"
assert_file "$AG_SCN"  "atdd-scenario agent shipped"
assert_file "$AG_MRG"  "atdd-merge agent shipped"
assert_hasE "$AG_SCN" "^name: atdd-scenario"   "atdd-scenario agent name matches agentType"
assert_hasE "$AG_MRG" "^name: atdd-merge"      "atdd-merge agent name matches agentType"
assert_has  "$RUN" "atdd-stage3.workflow.mjs"  "atdd-run references the workflow scriptPath"
assert_has  "$RUN" "stage3_mode"               "atdd-run gates on stage3_mode"
assert_hasE "$RUN" "[Cc]apability check|fall back to sequential" "atdd-run has a capability fallback"
echo

echo "[10] Non-blocking watch + interview dedup + conventions cache (R5/R9)"
SGEN="skills/spec/spec-generate/SKILL.md"
assert_hasE "$PAM"  "Monitor|run_in_background|background" "pr-auto-merge watch is non-blocking on Claude Code"
assert_hasE "$PAM"  "[Rr]e-entran|re-derive"               "pr-auto-merge watch re-derives state on resume"
assert_hasE "$PAM"  "--watch"                              "pr-auto-merge keeps the blocking watch as Codex fallback"
assert_hasE "$SGEN" "do NOT re-ask|answered ground|thread them forward" "spec-generate forwards captured fields instead of re-interviewing"
assert_has  "$WF"   "conventions"                          "workflow accepts a conventions cache for fan-out agents"
echo

echo "----------------------------------------"
printf 'contracts: %s passed, %s failed\n' "$(green "$pass")" "$( [ "$fail" -gt 0 ] && red "$fail" || echo "$fail")"
[ "$fail" -eq 0 ]
