#!/usr/bin/env bash
# Stop hook — Goal Loop Controller with Review Phase
#
# Phase 1: in_progress goal exists → block (resume it)
# Phase 2: pending goals exist → block (start next)
# Phase 3: unreviewed done goals → block with inline review instructions
#          (current Claude instance reviews via Bash tool — no subprocess)
# Phase 4: all reviewed, nothing pending → approve (Claude stops cleanly)
#
# Output: JSON {"decision": "block", "reason": "..."} or exit 0 to approve

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

GOALS_FILE="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}/goals.json"
REVIEW_START_FILE="/tmp/claude-worker-review-started"
REVIEW_TIMEOUT=300  # 5 minutes

emit_event() {
  local json="$1"
  curl -sf -X POST "${CLAUDE_WORKER_API:-http://localhost:4200}/events" \
    -H "Content-Type: application/json" \
    -d "$json" \
    --max-time 1 -o /dev/null 2>/dev/null || true
}

if [ ! -f "$GOALS_FILE" ]; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "check-goals" "no-goals-file" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

# ── Phase 1: resume in_progress ──────────────────────────────────────────────

IN_PROGRESS=$(jq '[.[] | select(.status == "in_progress")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$IN_PROGRESS" -gt 0 ]; then
  STUCK=$(jq -c '[.[] | select(.status == "in_progress")][0]' "$GOALS_FILE")
  STUCK_ID=$(echo "$STUCK" | jq -r '.id')
  STUCK_DESC=$(echo "$STUCK" | jq -r '.goal')
  emit_event "{\"type\":\"goal_loop\",\"phase\":1,\"goal_id\":\"$STUCK_ID\"}"
  update_state '.goal_status = "in_progress"' 2>/dev/null || true
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "check-goals" "in_progress" "$ELAPSED" 2>/dev/null || true
  jq -n --arg r "Goal id=$STUCK_ID is in_progress and needs completion. goal=\"$STUCK_DESC\". Continue working on it." \
    '{"decision": "block", "reason": $r}'
  exit 0
fi

# ── Phase 2: next pending goal ────────────────────────────────────────────────

PENDING=$(jq '[.[] | select(.status == "pending")] | length' "$GOALS_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  NEXT_GOAL=$(jq -c '[.[] | select(.status == "pending")][0]' "$GOALS_FILE" 2>/dev/null)
  NEXT_ID=$(echo "$NEXT_GOAL" | jq -r '.id')
  NEXT_DESC=$(echo "$NEXT_GOAL" | jq -r '.goal')
  emit_event "{\"type\":\"goal_loop\",\"phase\":2,\"pending\":$PENDING,\"next_id\":\"$NEXT_ID\"}"
  update_state '.goal_status = "started"' 2>/dev/null || true
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "check-goals" "started" "$ELAPSED" 2>/dev/null || true
  SESSION_NOTE=""
  SESSION_FILE=$(ls -t "${WORKER_HOME}/workspace/.claude/sessions/"*.md 2>/dev/null | head -1 || echo "")
  [ -n "$SESSION_FILE" ] && SESSION_NOTE=" Prior session state at: $SESSION_FILE — read it before starting."
  jq -n --arg r "$PENDING pending goal(s) remain. Next goal: id=$NEXT_ID goal=\"$NEXT_DESC\". Mark it in_progress with jq and work on it.${SESSION_NOTE}" \
    '{"decision": "block", "reason": $r}'
  exit 0
fi

# ── Phase 3: review unreviewed done goals (inline — no subprocess) ────────────
# Block with a CONTINUE prompt so the *current* Claude instance reviews completed
# goals using its own Bash tool. No new process spawned — avoids OOM.
#
# Timeout: if Phase 3 has been active for >= REVIEW_TIMEOUT seconds with no
# progress, auto-approve all unreviewed done goals and allow exit.

if [ -f "$REVIEW_START_FILE" ]; then
  review_started=$(cat "$REVIEW_START_FILE")
  now=$(date +%s)
  elapsed=$((now - review_started))

  if [ "$elapsed" -ge "$REVIEW_TIMEOUT" ]; then
    # Timeout — auto-approve all unreviewed done goals
    if command -v jq >/dev/null 2>&1 && [ -f "$GOALS_FILE" ]; then
      now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      jq --arg ts "$now_iso" '
        map(if .status == "done" and (.reviewed_at == null or .reviewed_at == "") then
          .reviewed_at = $ts |
          .review_score = 5 |
          .review_note = "AUTO-APPROVED: review timed out after 5 minutes"
        else . end)
      ' "$GOALS_FILE" > /tmp/goals-timeout.tmp \
        && mv /tmp/goals-timeout.tmp "$GOALS_FILE"
    fi
    rm -f "$REVIEW_START_FILE"
    update_state '.goal_status = "auto-approved"' 2>/dev/null || true
    # Fall through — Phase 3 check below will now find no unreviewed goals
  fi
fi

UNREVIEWED=$(jq '[.[] | select(.status == "done" and (.reviewed_at == null or .reviewed_at == ""))]' "$GOALS_FILE" 2>/dev/null)
UNREVIEWED_COUNT=$(echo "$UNREVIEWED" | jq 'length' 2>/dev/null || echo "0")

if [ "$UNREVIEWED_COUNT" -eq 0 ]; then
  rm -f "$REVIEW_START_FILE"
  emit_event "{\"type\":\"session_end\"}"
  GOAL_STATUS=$(read_state '.goal_status // "none"' 2>/dev/null || echo "none")
  # auto-approved was already set above if timeout triggered; otherwise mark completed
  if [ "$GOAL_STATUS" = "none" ] || [ "$GOAL_STATUS" = "null" ]; then
    update_state '.goal_status = "completed"' 2>/dev/null || true
  fi
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  GOAL_STATUS=$(read_state '.goal_status // "none"' 2>/dev/null || echo "none")
  log_hook "check-goals" "$GOAL_STATUS" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

# Record the time Phase 3 was first entered (for timeout tracking across invocations)
if [ ! -f "$REVIEW_START_FILE" ]; then
  date +%s > "$REVIEW_START_FILE"
fi

# Write goals to a temp file — avoids shell-expansion issues with arbitrary text in goal/result fields
GOALS_TMP=$(mktemp /tmp/claude-worker-review-XXXXXX.json)
echo "$UNREVIEWED" | jq 'map({id, goal, result})' > "$GOALS_TMP"

REASON="All active goals are done. Please review the $UNREVIEWED_COUNT completed goal(s) before finishing.

Read the goals from: $GOALS_TMP

Score each result 0-10:
- 10: Fully complete, verified working, production-ready
- 9:  Complete with trivial/cosmetic issues only
- <9: Incomplete, unverified, or incorrect — needs a fix goal

Use Bash to update $GOALS_FILE for each goal:
- Set reviewed_at to the current UTC timestamp (date -u +%Y-%m-%dT%H:%M:%SZ)
- If score < 9, append a new pending goal object describing the exact fix needed

The next stop hook will automatically pick up any new pending fix goals."

emit_event "{\"type\":\"review_start\",\"count\":$UNREVIEWED_COUNT}"
update_state '.goal_status = "reviewing"' 2>/dev/null || true
ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-goals" "reviewing" "$ELAPSED" 2>/dev/null || true
jq -n --arg r "$REASON" '{"decision": "block", "reason": $r}'
exit 0
