#!/usr/bin/env bash
# atdd-pipeline PreToolUse guard: refuse merges into the trunk branch, deterministically.
#
# Enforces design principle #4 (scenario sub-PRs target the integration branch, never the
# trunk) and hardens the final-PR human gate (#2) outside the model. The prose rule in
# pr-auto-merge / green-cycle stays as the Codex-side fallback; this hook is the
# Claude-Code-only enforcement layer. Wired via hooks/hooks.json on PreToolUse(Bash).
#
# Reads the tool-call JSON on stdin, inspects tool_input.command, and exits 2 (block) with
# an explanation on stderr when the command would merge or push into trunk.
#
# Scope: only repos that opt into the pipeline (a .atdd-pipeline.json is present). In any
# other repo the hook is a no-op, so installing the plugin does not interfere with normal
# `gh pr merge` elsewhere.
#
# Fail-closed: when a `gh pr merge` base cannot be resolved, the merge is blocked rather
# than allowed — a false block just means the human merges manually.

set -uo pipefail

payload="$(cat)"

# jq parses the hook payload. Without it we cannot read the command; do not pretend to guard.
if ! command -v jq >/dev/null 2>&1; then
  echo "atdd-pipeline guard-merge: jq not found; merge guard inactive for this call." >&2
  exit 0
fi

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0   # nothing to inspect

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
workdir="${cwd:-$PWD}"

# Locate .atdd-pipeline.json in the working dir or the git toplevel. Absent => not a
# pipeline-managed repo => do not guard.
find_cfg() {
  if [ -f "$workdir/.atdd-pipeline.json" ]; then
    printf '%s\n' "$workdir/.atdd-pipeline.json"; return 0
  fi
  local top
  top="$( (cd "$workdir" 2>/dev/null && git rev-parse --show-toplevel) 2>/dev/null )"
  if [ -n "$top" ] && [ -f "$top/.atdd-pipeline.json" ]; then
    printf '%s\n' "$top/.atdd-pipeline.json"; return 0
  fi
  return 1
}
cfg="$(find_cfg)" || exit 0

# Protected trunk names: the configured trunk_branch plus the usual defaults.
protected=("main" "master")
configured_trunk="$(jq -r '.trunk_branch // empty' "$cfg" 2>/dev/null)"
[ -n "$configured_trunk" ] && protected=("$configured_trunk" "main" "master")

is_trunk() {
  local b="$1" t
  for t in "${protected[@]}"; do [ "$b" = "$t" ] && return 0; done
  return 1
}

deny() {
  echo "atdd-pipeline guard-merge: BLOCKED — $1" >&2
  exit 2
}

case "$cmd" in
  *"gh pr merge"*)
    # An explicit PR number / URL / branch may follow `gh pr merge`; otherwise gh resolves
    # the current branch's PR. The first token after `merge` that is not a flag is it.
    pr="$(printf '%s' "$cmd" \
      | grep -oiE 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+[^-][^[:space:]]*' \
      | head -n1 | awk '{print $NF}')"
    base="$( (cd "$workdir" 2>/dev/null && gh pr view ${pr:+"$pr"} --json baseRefName -q .baseRefName) 2>/dev/null )"
    [ -z "$base" ] && deny "cannot resolve the base branch of '$cmd' (fail-closed). Confirm base != trunk, then merge by hand."
    is_trunk "$base" && deny "PR base is '$base' (trunk). Scenario sub-PRs merge into the integration branch; the integration->trunk PR is a human gate."
    ;;
  *"gh api"*"/merges"*)
    deny "direct GitHub merge API call ('gh api .../merges') bypasses the merge gate. Use 'gh pr merge' against the integration branch."
    ;;
  *"git push"*)
    # Block only the cross-ref form `git push ... <src>:<dst>` where dst is trunk and src is
    # not — i.e. pushing scenario work onto trunk. A plain `git push origin main` that
    # fast-forwards trunk onto itself is intentionally left alone.
    refspec="$(printf '%s' "$cmd" | grep -oE '[^[:space:]]+:[^[:space:]]+' | head -n1)"
    if [ -n "$refspec" ]; then
      src="${refspec%%:*}"; dst="${refspec##*:}"
      src="${src#refs/heads/}"; dst="${dst#refs/heads/}"
      if is_trunk "$dst" && ! is_trunk "$src"; then
        deny "push '$refspec' writes '$src' onto trunk '$dst'. The pipeline never pushes scenario work onto trunk."
      fi
    fi
    ;;
esac

exit 0
