#!/usr/bin/env bash
# PreToolUse/Bash hook — detect command loops and failure-retry patterns.
#
# Tracks normalized commands per session. Warns at escalating thresholds.
# Uses fuzzy matching: strips paths and flag values before comparing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true

START_MS=$(($(date +%s%N) / 1000000))

# Read hook JSON from stdin
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

# Normalize command for fuzzy matching
NORMALIZED=$(echo "$CMD" | \
  sed 's|/[^ ]*||g' | \
  sed 's/--[a-z-]*=[^ ]*//g' | \
  tr -s ' ' | \
  xargs)
[ -z "$NORMALIZED" ] && exit 0

# Per-session tracking file
LOOP_FILE="/tmp/claude-loop-${CLAUDE_SESSION_ID:-$$}.log"

# Append normalized command
echo "$NORMALIZED" >> "$LOOP_FILE"

# Count consecutive identical commands from the tail
COUNT=0
if [ -f "$LOOP_FILE" ]; then
  COUNT=$(tac "$LOOP_FILE" | while IFS= read -r line; do
    [ "$line" = "$NORMALIZED" ] && echo "match" || break
  done | wc -l)
fi

# Update shared state
init_state 2>/dev/null || true
update_state ".loop_count = $COUNT" 2>/dev/null || true

RESULT="ok"

# Escalation thresholds
if [ "$COUNT" -ge 12 ]; then
  RESULT="loop-critical"
  cat >&2 << 'WARN'

⚠ Loop detected (12+ repetitions of the same command pattern).
Consider using /systematic-debugging to find the root cause instead of retrying.

WARN
elif [ "$COUNT" -ge 8 ]; then
  RESULT="loop-warning"
  echo "⚠ Possible loop ($COUNT repetitions of similar command). Consider a different approach." >&2
elif [ "$COUNT" -ge 5 ]; then
  RESULT="loop-notice"
  echo "⚠ Same command pattern repeated $COUNT times." >&2
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-loop" "$RESULT" "$ELAPSED" "\"count\":$COUNT" 2>/dev/null || true

exit 0
