#!/usr/bin/env bash
# PreToolUse/Bash hook: warn Claude when the same command is repeated >= 5 times
# Exit 0 always — this is advisory only, never blocks execution

set -euo pipefail

# Require jq
command -v jq &>/dev/null || exit 0

# Read tool input from stdin
INPUT=$(cat)

# Extract command using jq; normalize whitespace via bash
RAW_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Normalize: collapse internal whitespace
COMMAND=$(echo "$RAW_CMD" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')

# Skip empty commands
[ -z "$COMMAND" ] && exit 0

# Session file — use CLAUDE_SESSION_ID if set, else fall back to fixed file
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_ID="${SESSION_ID//[^a-zA-Z0-9_-]/}"
[ -z "$SESSION_ID" ] && SESSION_ID="default"
STATE_FILE="/tmp/claude-loop-${SESSION_ID}.json"

# Load or init state: { "commands": ["cmd1", "cmd2", ...] } (last 20 only)
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
else
    STATE='{"commands":[]}'
fi

# Append current command and keep last 20
NEW_STATE=$(echo "$STATE" | jq --arg cmd "$COMMAND" \
    '.commands += [$cmd] | .commands = (.commands | .[-20:])' \
    2>/dev/null || echo '{"commands":[]}')

echo "$NEW_STATE" > "$STATE_FILE" 2>/dev/null || true

# Count consecutive identical commands from the end
COUNT=$(echo "$NEW_STATE" | jq --arg cmd "$COMMAND" '
    .commands as $cmds |
    ($cmds | length) as $len |
    reduce range($len - 1; -1; -1) as $i (
        {"count": 0, "done": false};
        if .done then . else
            if $cmds[$i] == $cmd then .count += 1
            else .done = true
            end
        end
    ) | .count
' 2>/dev/null || echo "0")

# Warn at 5, 10 repetitions
if [ "$COUNT" -ge 10 ]; then
    echo "Warning: identical command repeated ${COUNT} times in a row. You appear to be stuck in a loop. Stop and reconsider your approach — check error messages, try a different strategy, or ask for help."
elif [ "$COUNT" -ge 5 ]; then
    echo "Warning: identical command repeated ${COUNT} times consecutively. Consider whether a different approach is needed."
fi

exit 0
