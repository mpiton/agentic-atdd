#!/usr/bin/env bash
# DEPRECATED. Codex CLI discovers skills directly from ~/.codex/skills/<name>/SKILL.md
# in the same format as Claude Code. install.sh now symlinks every skill into both
# ~/.claude/skills/ AND ~/.codex/skills/ in a single pass.
#
# This script is kept as an alias that re-runs install.sh, so existing muscle memory
# and any documentation referencing it still works.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[atdd-pipeline] sync-codex.sh is deprecated; delegating to install.sh"
exec "$SCRIPT_DIR/install.sh" "$@"
