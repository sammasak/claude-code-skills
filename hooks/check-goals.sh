#!/usr/bin/env bash
# Stop hook — Goal Loop Controller with Review Phase
#
# Phase 1: in_progress goal exists → CONTINUE (resume it)
# Phase 2: pending goals exist → CONTINUE (start next)
# Phase 3: unreviewed done goals → run claude -p review, add fix goals if score < 9/10
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

# ── Phase 3: review unreviewed done goals ─────────────────────────────────────

UNREVIEWED=$(jq '[.[] | select(.status == "done" and (.reviewed_at == null or .reviewed_at == ""))]' "$GOALS_FILE" 2>/dev/null)
UNREVIEWED_COUNT=$(echo "$UNREVIEWED" | jq 'length' 2>/dev/null || echo "0")

if [ "$UNREVIEWED_COUNT" -eq 0 ]; then
  exit 0
fi

# Build review prompt with goal summaries
GOALS_JSON=$(echo "$UNREVIEWED" | jq 'map({id, goal, result})')
REVIEW_PROMPT="You are a strict autonomous agent goal reviewer. Review each completed goal and its result.

Score each goal 0-10:
- 10: Fully complete, verified working, production-ready
- 9: Complete with only cosmetic/trivial issues
- <9: Missing verification, incomplete implementation, unconfirmed result, or incorrect output

For each score below 9, write a specific actionable follow-up goal that fixes the exact issue.

Return ONLY valid JSON, no markdown fences, no explanation:
{
  \"reviews\": [
    {\"id\": \"<goal_id>\", \"score\": <0-10>, \"issue\": \"<what is missing or wrong>\", \"fix_goal\": \"<specific actionable goal to fix it>\"}
  ],
  \"new_goals\": [\"<fix goal text>\"]
}

Completed goals to review:
${GOALS_JSON}"

# Run review via claude -p (spawns new headless session)
REVIEW_OUTPUT=$(claude -p "$REVIEW_PROMPT" \
  --output-format json \
  --dangerously-skip-permissions \
  --no-session-persistence \
  2>/dev/null)

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Mark all unreviewed done goals as reviewed — do this before parsing results
# so a failed review still prevents an infinite loop
REVIEWED_IDS=$(echo "$UNREVIEWED" | jq -r '.[].id')
while IFS= read -r rid; do
  [ -z "$rid" ] && continue
  jq --arg id "$rid" --arg ts "$NOW" \
    'map(if .id == $id then .reviewed_at = $ts else . end)' \
    "$GOALS_FILE" > "${GOALS_FILE}.tmp" && mv "${GOALS_FILE}.tmp" "$GOALS_FILE"
done <<< "$REVIEWED_IDS"

if [ -z "$REVIEW_OUTPUT" ]; then
  exit 0
fi

# Extract response text from claude --output-format json wrapper
RESPONSE_TEXT=$(echo "$REVIEW_OUTPUT" | jq -r '.result // ""' 2>/dev/null)

# Parse new fix goals (empty if all scored >= 9)
NEW_GOALS=$(echo "$RESPONSE_TEXT" | jq -r '.new_goals[]?' 2>/dev/null)

# Append fix goals to goals.json
ADDED=0
while IFS= read -r goal_text; do
  [ -z "$goal_text" ] && continue
  NEW_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
  NEW_GOAL=$(jq -n \
    --arg id "$NEW_ID" \
    --arg goal "$goal_text" \
    --arg ts "$NOW" \
    '{id: $id, goal: $goal, status: "pending", created_at: $ts,
      started_at: null, completed_at: null, reviewed_at: null, result: null}')
  jq --argjson ng "$NEW_GOAL" '. + [$ng]' \
    "$GOALS_FILE" > "${GOALS_FILE}.tmp" && mv "${GOALS_FILE}.tmp" "$GOALS_FILE"
  ADDED=$((ADDED + 1))
done <<< "$NEW_GOALS"

if [ "$ADDED" -gt 0 ]; then
  echo "CONTINUE: Review phase added $ADDED fix goal(s) scoring below 9/10. Work on the new pending goals."
fi

# ADDED == 0 means all goals scored >= 9/10 — exit silently, Claude stops cleanly
