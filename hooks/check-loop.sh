#!/usr/bin/env bash
# PreToolUse Bash hook — detect command loops.
# Tracks normalized commands per session; warns at escalating thresholds.
# Fuzzy matching: strips paths and flag values before comparing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input

START_MS=$(($(date +%s%N) / 1000000))

CMD=$(hook_command)
[ -z "$CMD" ] && exit 0

NORMALIZED=$(echo "$CMD" | \
  sed 's|/[^ ]*||g' | \
  sed 's/--[a-z-]*=[^ ]*//g' | \
  tr -s ' ' | \
  xargs)
[ -z "$NORMALIZED" ] && exit 0

LOOP_FILE="/tmp/claude-loop-${CLAUDE_SESSION_ID}.log"
find /tmp -maxdepth 1 -name 'claude-loop-*.log' -mtime +2 -delete 2>/dev/null || true

echo "$NORMALIZED" >> "$LOOP_FILE"

COUNT=$(tac "$LOOP_FILE" | while IFS= read -r line; do
  [ "$line" = "$NORMALIZED" ] && echo "match" || break
done | wc -l)

init_state 2>/dev/null || true
update_state ".loop_count = $COUNT" 2>/dev/null || true

RESULT="ok"
if [ "$COUNT" -ge 12 ]; then
  RESULT="loop-critical"
  echo "Loop detected ($COUNT repetitions of the same command pattern). Use systematic debugging to find the root cause instead of retrying." >&2
  inc_state 'errors_seen' 2>/dev/null || true
elif [ "$COUNT" -ge 8 ]; then
  RESULT="loop-warning"
  echo "Possible loop ($COUNT repetitions of similar command). Consider a different approach." >&2
  inc_state 'errors_seen' 2>/dev/null || true
elif [ "$COUNT" -ge 5 ]; then
  RESULT="loop-notice"
  echo "Same command pattern repeated $COUNT times." >&2
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-loop" "$RESULT" "$ELAPSED" "{\"count\":$COUNT}" 2>/dev/null || true

exit 0
