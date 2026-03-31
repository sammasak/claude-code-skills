#!/usr/bin/env bash
# Stop hook — write structured session state file at goal completion.
# VM ONLY (guard: no-ops on physical host where goals.json is absent).
# Fires AFTER check-goals.sh and extract-instincts.sh.
# Only writes when all goals are done+reviewed (no active goals remaining).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/log.sh"
START_MS=$(($(date +%s%N) / 1000000))

# Guard: physical host no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
GOALS_FILE="$WORKER_HOME/goals.json"
[ ! -f "$GOALS_FILE" ] && exit 0

# Only write when truly stopping (no pending/in_progress goals)
ACTIVE=$(jq '[.[] | select(.status == "pending" or .status == "in_progress")] | length' \
  "$GOALS_FILE" 2>/dev/null || echo "1")
[ "$ACTIVE" -gt 0 ] && exit 0

# Read goal_status from shared state (written by check-goals.sh earlier in Stop chain)
init_state
GOAL_STATUS=$(read_state '.goal_status // "n/a"' || echo "n/a")

# Build goals summary from goals.json
GOALS_SUMMARY=$(jq -r '.[] | "\(.status): \(.goal[0:80])"' "$GOALS_FILE" 2>/dev/null | head -10 || echo "n/a")

# Find most recently completed goal
LAST_GOAL=$(jq -c '[.[] | select(.status == "done")] | sort_by(.completed_at) | last' \
  "$GOALS_FILE" 2>/dev/null || echo "null")
[ -z "$LAST_GOAL" ] || [ "$LAST_GOAL" = "null" ] && exit 0

# Read Stop hook JSON from stdin — must be done before any other processing
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

GOAL_ID=$(echo "$LAST_GOAL" | jq -r '.id')
GOAL_TEXT=$(echo "$LAST_GOAL" | jq -r '.goal')
GOAL_RESULT=$(echo "$LAST_GOAL" | jq -r '.result // "No result recorded"')

# Prepare sessions directory
SESSIONS_DIR="$WORKER_HOME/workspace/.claude/sessions"
mkdir -p "$SESSIONS_DIR"

DATE=$(date -u +%Y-%m-%d)
SHORT_ID="${GOAL_ID:0:8}"
STATE_FILE="$SESSIONS_DIR/${DATE}-${SHORT_ID}.md"

# Collect mechanical state (git log + recent files)
GIT_LOG=""
if git -C "$WORKER_HOME/workspace" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_LOG=$(git -C "$WORKER_HOME/workspace" log --oneline -10 2>/dev/null || echo "no commits")
fi

RECENT_FILES=$(find "$WORKER_HOME/workspace" -newer "$GOALS_FILE" -type f \
  -not -path "*/node_modules/*" -not -path "*/.git/*" \
  2>/dev/null | head -20 | sed "s|$WORKER_HOME/workspace/||" || echo "none")

# Write header + mechanical section immediately
cat > "$STATE_FILE" << STATEEOF
# Session State — Goal ${GOAL_ID}
**Date:** ${DATE}
**Goal:** ${GOAL_TEXT}
**Result:** ${GOAL_RESULT}

## 5. Current File State

### Recent Git Commits
${GIT_LOG:-No git repository or no commits}

### Recently Modified Files
${RECENT_FILES}

---
STATEEOF

# Load prompt template (external file with fallback)
TEMPLATE_DIR="$HOME/workspace/workflows/hooks/write-session-state"
if [ -f "$TEMPLATE_DIR/handoff-document.md" ]; then
  TEMPLATE=$(cat "$TEMPLATE_DIR/handoff-document.md")
else
  # Inline fallback
  TEMPLATE='Write a structured session handoff. Goal status: {{GOAL_STATUS}}. Git: {{GIT_LOG}}. Files: {{RECENT_FILES}}. Transcript: {{TURNS}}. Output markdown sections: What We Built, What Worked, What Did NOT Work, Open Questions, Next Steps.'
fi

# Use transcript path read from stdin at script start
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  ASSISTANT_TURNS=$(jq -r '
    select(.type == "assistant") |
    (.message.content // []) |
    map(select(.type == "text") | .text) |
    join("") | .[0:800]
  ' "$TRANSCRIPT" 2>/dev/null | tail -60)

  if [ -n "$ASSISTANT_TURNS" ]; then
    # Interpolate template variables
    PROMPT_TEXT=$(echo "$TEMPLATE" | \
      sed "s|{{GOAL_STATUS}}|$GOAL_STATUS|g" | \
      sed "s|{{GOALS_SUMMARY}}|$GOALS_SUMMARY|g" | \
      sed "s|{{GIT_LOG}}|$GIT_LOG|g" | \
      sed "s|{{RECENT_FILES}}|$RECENT_FILES|g")

    EXTRACTION=$(claude -p \
      --model claude-haiku-4-5-20251001 \
      "Goal was: $GOAL_TEXT

$PROMPT_TEXT

Session transcript (recent):
$ASSISTANT_TURNS" 2>/dev/null || echo "")

    [ -n "$EXTRACTION" ] && echo "$EXTRACTION" >> "$STATE_FILE"
  fi
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "write-session-state" "wrote" "$ELAPSED"

exit 0
