#!/usr/bin/env bash
# Stop hook — write structured session state file at goal completion.
# VM ONLY (guard: no-ops on physical host where goals.json is absent).
# Fires AFTER check-goals.sh and extract-instincts.sh.
# Only writes when all goals are done+reviewed (no active goals remaining).

set -euo pipefail

# Guard: physical host no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
GOALS_FILE="$WORKER_HOME/goals.json"
[ ! -f "$GOALS_FILE" ] && exit 0

# Only write when truly stopping (no pending/in_progress goals)
ACTIVE=$(jq '[.[] | select(.status == "pending" or .status == "in_progress")] | length' \
  "$GOALS_FILE" 2>/dev/null || echo "1")
[ "$ACTIVE" -gt 0 ] && exit 0

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

# Use transcript path read from stdin at script start
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  ASSISTANT_TURNS=$(jq -r '
    select(.type == "assistant") |
    (.message.content // []) |
    map(select(.type == "text") | .text) |
    join("") | .[0:800]
  ' "$TRANSCRIPT" 2>/dev/null | tail -60)

  if [ -n "$ASSISTANT_TURNS" ]; then
    EXTRACTION=$(claude -p \
      --model claude-haiku-4-5-20251001 \
      "Fill in these sections for a session handoff document. Be specific and terse.
Goal was: $GOAL_TEXT
Transcript excerpt: $ASSISTANT_TURNS

Output ONLY the following sections (use ## headers exactly):
## 1. What We Built
## 2. What Worked
## 3. What Did NOT Work
## 4. What Hasn't Been Tried
## 6. Decisions Made
## 7. Blockers
## 8. Exact Next Step" 2>/dev/null || echo "")

    [ -n "$EXTRACTION" ] && echo "$EXTRACTION" >> "$STATE_FILE"
  fi
fi

exit 0
