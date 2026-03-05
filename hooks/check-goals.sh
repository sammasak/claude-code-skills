#!/usr/bin/env bash
# Stop hook — Goal Loop Controller
# When Claude tries to stop, check for pending goals.
# If any remain, print a message (causing Claude to continue).
# If none remain, exit silently (Claude stops cleanly).

GOALS_FILE="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}/goals.json"

if [ ! -f "$GOALS_FILE" ]; then
  exit 0
fi

IN_PROGRESS=$(jq '[.[] | select(.status == "in_progress")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$IN_PROGRESS" -gt 0 ]; then
  STUCK=$(jq -c '[.[] | select(.status == "in_progress")][0]' "$GOALS_FILE")
  STUCK_ID=$(echo "$STUCK" | jq -r '.id')
  STUCK_DESC=$(echo "$STUCK" | jq -r '.goal')
  echo "CONTINUE: Goal id=$STUCK_ID is in_progress and needs completion. goal=\"$STUCK_DESC\". Continue working on it."
  exit 0
fi

PENDING=$(jq '[.[] | select(.status == "pending")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  NEXT_GOAL=$(jq -c '[.[] | select(.status == "pending")][0]' "$GOALS_FILE" 2>/dev/null)
  NEXT_ID=$(echo "$NEXT_GOAL" | jq -r '.id')
  NEXT_DESC=$(echo "$NEXT_GOAL" | jq -r '.goal')
  echo "CONTINUE: $PENDING pending goal(s) remain. Next goal: id=$NEXT_ID goal=\"$NEXT_DESC\". Mark it in_progress with jq and work on it."
fi

# If PENDING == 0 and IN_PROGRESS == 0: silent exit → Claude stops cleanly
