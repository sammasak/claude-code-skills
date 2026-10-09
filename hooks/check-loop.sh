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

# Feedback channels: below the critical threshold the warning rides stdout
# JSON additionalContext (advisory, command still runs); at 12+ exit 2 blocks
# the repeat and feeds the message to the model.
RESULT="ok"
if [ "$COUNT" -ge 12 ]; then
  RESULT="loop-critical"
  inc_state 'errors_seen' 2>/dev/null || true
  log_hook "check-loop" "$RESULT" "$(( ($(date +%s%N) / 1000000) - START_MS ))" "{\"count\":$COUNT}" 2>/dev/null || true
  echo "Loop detected: $COUNT repetitions of the same command pattern. Use systematic debugging to find the root cause instead of retrying." >&2
  exit 2
elif [ "$COUNT" -ge 5 ]; then
  [ "$COUNT" -ge 8 ] && RESULT="loop-warning" || RESULT="loop-notice"
  [ "$COUNT" -ge 8 ] && inc_state 'errors_seen' 2>/dev/null || true
  jq -cn --arg ctx "Same command pattern repeated $COUNT times this session; consider a different approach." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-loop" "$RESULT" "$ELAPSED" "{\"count\":$COUNT}" 2>/dev/null || true

exit 0
