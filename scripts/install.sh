#!/usr/bin/env bash
# Install the atdd-pipeline plugin into the user's Claude Code (and Codex) setup:
#   - skills      -> symlinked into ~/.claude/skills and ~/.codex/skills
#   - commands    -> slash-command stubs in ~/.claude/commands
#   - agents      -> symlinked into ~/.claude/agents (Claude Code only)
#   - trunk-merge hook -> registered in ~/.claude/settings.json (Claude Code only)
#
# Codex installs get skills only: it has no subagent or hook system, so agents and the
# trunk-merge hook are skipped there. Hook registration needs `jq` — without it the script
# warns and leaves the hook unregistered (skills, commands, and agents still install).
#
# The `/plugin install` flow is the recommended path and auto-discovers agents/hooks/
# workflows for you; this script is the manual / Codex fallback and wires the Claude-only
# pieces by hand so a symlink install gets the same enforcement.
#
# Usage:
#   ./install.sh                  # install for current user (~/.claude)
#   CLAUDE_HOME=/path ./install   # install into a custom CLAUDE_HOME
#
# Idempotent: re-running replaces the symlinks in place and never double-registers the hook.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SKILLS_DIR="$CLAUDE_HOME/skills"
COMMANDS_DIR="$CLAUDE_HOME/commands"
CODEX_SKILLS_DIR="$CODEX_HOME/skills"

mkdir -p "$SKILLS_DIR" "$COMMANDS_DIR"

echo "[atdd-pipeline] installing skills into $SKILLS_DIR"

# Symlink every skill folder under skills/<bucket>/<name> as $SKILLS_DIR/<name>.
# Mirror the same symlink into $CODEX_HOME/skills/<name> when Codex is installed.
codex_present=false
if [[ -d "$CODEX_HOME" ]]; then
  mkdir -p "$CODEX_SKILLS_DIR"
  codex_present=true
  echo "[atdd-pipeline] also installing skills into $CODEX_SKILLS_DIR"
fi

while IFS= read -r skill_md; do
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  for target_dir in "$SKILLS_DIR" $([[ "$codex_present" == "true" ]] && echo "$CODEX_SKILLS_DIR"); do
    target="$target_dir/$name"
    if [[ -L "$target" || -e "$target" ]]; then
      rm -rf "$target"
    fi
    ln -s "$skill_dir" "$target"
    echo "  + $target -> $skill_dir"
  done
done < <(find "$PLUGIN_DIR/skills" -name SKILL.md -type f)

echo "[atdd-pipeline] installing slash commands into $COMMANDS_DIR"

# Map plugin.json commands -> slash command files that delegate to the skill.
# Plain bash JSON parsing: rely on jq if available, otherwise a small grep parser.
plugin_json="$PLUGIN_DIR/.claude-plugin/plugin.json"
if command -v jq >/dev/null 2>&1; then
  mapfile -t entries < <(jq -r '.commands[] | "\(.name)\t\(.skill)"' "$plugin_json")
else
  mapfile -t entries < <(
    awk '
      /"commands"/ {in_cmd=1; next}
      in_cmd && /"name"/ {gsub(/[",]/,""); name=$2}
      in_cmd && /"skill"/ {gsub(/[",]/,""); print name"\t"$2}
      in_cmd && /\]/ {in_cmd=0}
    ' "$plugin_json"
  )
fi

for entry in "${entries[@]}"; do
  cmd_name="${entry%%$'\t'*}"
  skill_name="${entry##*$'\t'}"
  cmd_file="$COMMANDS_DIR/$cmd_name.md"
  cat > "$cmd_file" <<EOF
---
description: Invoke the $skill_name skill (atdd-pipeline).
---

Invoke the \`$skill_name\` skill via the Skill tool. Pass through any arguments the user provided.
EOF
  echo "  + /$cmd_name -> $skill_name"
done

# --- Agents (Claude Code only; Codex has no subagent system) ---------------------------
# Symlink each agents/<name>.md into $CLAUDE_HOME/agents so the Stage 3 workflow's
# agentType dispatch (atdd-scenario, atdd-merge) resolves on a manual install.
AGENTS_SRC="$PLUGIN_DIR/agents"
AGENTS_DIR="$CLAUDE_HOME/agents"
if [[ -d "$AGENTS_SRC" ]]; then
  mkdir -p "$AGENTS_DIR"
  echo "[atdd-pipeline] installing agents into $AGENTS_DIR"
  while IFS= read -r agent_md; do
    name="$(basename "$agent_md")"
    target="$AGENTS_DIR/$name"
    [[ -L "$target" || -e "$target" ]] && rm -rf "$target"
    ln -s "$agent_md" "$target"
    echo "  + $target -> $agent_md"
  done < <(find "$AGENTS_SRC" -maxdepth 1 -name '*.md' -type f)
fi

# --- Trunk-merge guard hook (Claude Code only) -----------------------------------------
# Register the PreToolUse hook in $CLAUDE_HOME/settings.json. Idempotent: skips if a hook
# already points at guard-merge.sh. Backs settings.json up before touching it.
GUARD="$PLUGIN_DIR/hooks/guard-merge.sh"
SETTINGS="$CLAUDE_HOME/settings.json"
if [[ -f "$GUARD" ]]; then
  if command -v jq >/dev/null 2>&1; then
    [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
    if jq -e --arg g "$GUARD" '[.hooks.PreToolUse[]?.hooks[]?.command // empty] | map(contains($g)) | any' "$SETTINGS" >/dev/null 2>&1; then
      echo "[atdd-pipeline] trunk-merge hook already registered in $SETTINGS"
    else
      cp "$SETTINGS" "$SETTINGS.atdd.bak"
      tmp="$(mktemp)"
      jq --arg g "$GUARD" '
        .hooks = (.hooks // {})
        | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [
            { matcher: "Bash", hooks: [ { type: "command", command: $g } ] }
          ])
      ' "$SETTINGS" > "$tmp" \
        && mv "$tmp" "$SETTINGS" \
        && echo "[atdd-pipeline] registered trunk-merge hook in $SETTINGS (backup: $SETTINGS.atdd.bak)" \
        || { echo "[atdd-pipeline] ERROR: failed to register trunk-merge hook in $SETTINGS" >&2; rm -f "$tmp"; exit 1; }
    fi
  else
    echo "[atdd-pipeline] WARN: jq not found — cannot auto-register the trunk-merge hook."
    echo "                add a PreToolUse(Bash) hook running $GUARD to $SETTINGS by hand (see hooks/README.md)."
  fi
fi

# --- Workflow mode note -----------------------------------------------------------------
echo "[atdd-pipeline] note: Stage 3 'workflow' mode (opt-in, experimental) resolves its script"
echo "                via \${CLAUDE_PLUGIN_ROOT}, which is only set under '/plugin install'. On this"
echo "                manual install Stage 3 stays in 'sequential' mode (the default)."

echo "[atdd-pipeline] done. Restart Claude Code (and Codex) to pick up new skills and agents."
