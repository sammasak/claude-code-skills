#!/usr/bin/env bash
# Stop hook — Goal Loop Controller with Review Phase
#
# Phase 1: in_progress goal exists → CONTINUE (resume it)
# Phase 2: pending goals exist → CONTINUE (start next)
# Phase 3: unreviewed done goals → CONTINUE with inline review instructions
#          (current Claude instance reviews via Bash tool — no subprocess)
# Phase 4: all reviewed, nothing pending → exit silently (Claude stops cleanly)

GOALS_FILE="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}/goals.json"

if [ ! -f "$GOALS_FILE" ]; then
  exit 0
fi

# ── Phase 1: resume in_progress ──────────────────────────────────────────────

IN_PROGRESS=$(jq '[.[] | select(.status == "in_progress")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$IN_PROGRESS" -gt 0 ]; then
  STUCK=$(jq -c '[.[] | select(.status == "in_progress")][0]' "$GOALS_FILE")
  STUCK_ID=$(echo "$STUCK" | jq -r '.id')
  STUCK_DESC=$(echo "$STUCK" | jq -r '.goal')
  echo "CONTINUE: Goal id=$STUCK_ID is in_progress and needs completion. goal=\"$STUCK_DESC\". Continue working on it."
  exit 0
fi

# ── Phase 2: next pending goal ────────────────────────────────────────────────

PENDING=$(jq '[.[] | select(.status == "pending")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  NEXT_GOAL=$(jq -c '[.[] | select(.status == "pending")][0]' "$GOALS_FILE" 2>/dev/null)
  NEXT_ID=$(echo "$NEXT_GOAL" | jq -r '.id')
  NEXT_DESC=$(echo "$NEXT_GOAL" | jq -r '.goal')
  echo "CONTINUE: $PENDING pending goal(s) remain. Next goal: id=$NEXT_ID goal=\"$NEXT_DESC\". Mark it in_progress with jq and work on it."
  exit 0
fi

# ── Phase 3: review unreviewed done goals (inline — no subprocess) ────────────
# Output a CONTINUE prompt so the *current* Claude instance reviews completed
# goals using its own Bash tool. No new process spawned — avoids the OOM and
# recursive stop-hook loop that plagued the previous claude -p approach.

UNREVIEWED=$(jq '[.[] | select(.status == "done" and (.reviewed_at == null or .reviewed_at == ""))]' "$GOALS_FILE" 2>/dev/null)
UNREVIEWED_COUNT=$(echo "$UNREVIEWED" | jq 'length' 2>/dev/null || echo "0")

if [ "$UNREVIEWED_COUNT" -eq 0 ]; then
  exit 0
fi

# Write goals to a temp file — avoids shell-expansion issues with arbitrary text in goal/result fields
GOALS_TMP=$(mktemp /tmp/claude-worker-review-XXXXXX.json)
echo "$UNREVIEWED" | jq 'map({id, goal, result})' > "$GOALS_TMP"

cat <<EOF
CONTINUE: All active goals are done. Please review the $UNREVIEWED_COUNT completed goal(s) before finishing.

Read the goals from: $GOALS_TMP

Score each result 0-10:
- 10: Fully complete, verified working, production-ready
- 9:  Complete with trivial/cosmetic issues only
- <9: Incomplete, unverified, or incorrect — needs a fix goal

Use Bash to update $GOALS_FILE for each goal:
- Set reviewed_at to the current UTC timestamp (date -u +%Y-%m-%dT%H:%M:%SZ)
- If score < 9, append a new pending goal object describing the exact fix needed

The next stop hook will automatically pick up any new pending fix goals.
EOF
