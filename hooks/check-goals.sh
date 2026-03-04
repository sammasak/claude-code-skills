#!/bin/bash
# Stop hook — Goal Loop Controller
# When Claude tries to stop, check for pending goals.
# If any remain, print a message (causing Claude to continue).
# If none remain, exit silently (Claude stops cleanly).

GOALS_FILE="/var/lib/claude-worker/goals.json"

if [ ! -f "$GOALS_FILE" ]; then
  exit 0
fi

PENDING=$(jq '[.[] | select(.status == "pending")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  echo "CONTINUE: $PENDING pending goal(s) remain in $GOALS_FILE. Read the file now, find the next pending goal, update its status to in_progress, and work on it."
fi

# If PENDING == 0: silent exit → Claude stops cleanly
