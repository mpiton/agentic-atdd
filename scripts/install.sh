#!/usr/bin/env bash
# Install the atdd-pipeline plugin's skills and slash commands into the
# user's Claude Code skill directory.
#
# Usage:
#   ./install.sh                  # install for current user (~/.claude)
#   CLAUDE_HOME=/path ./install   # install into a custom CLAUDE_HOME
#
# Idempotent: re-running replaces the symlinks in place.

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

echo "[atdd-pipeline] done. Restart Claude Code to pick up new skills."
