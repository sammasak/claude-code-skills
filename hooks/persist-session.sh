#!/usr/bin/env bash
# Stop hook — write AI session record to ~/workspace/sessions/ai-sessions/.
#
# Physical host ONLY. Fires first in the Stop chain.
# Uses prompt template from ~/workspace/workflows/hooks/persist-session/.
# Enriched with shared state (topic, repos, tools, errors).
#
# Note: session files are committed but not pushed. Run 'cd ~/workspace && git push'
# periodically to sync session history to remote. Pushing in the hook adds network
# dependency to the Stop chain which would delay Claude Code shutdown.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/log.sh"

START_MS=$(($(date +%s%N) / 1000000))

WORKSPACE="${HOME}/workspace"
HAIKU_MODEL="claude-haiku-4-5-20251001"
TEMPLATE_DIR="$WORKSPACE/workflows/hooks/persist-session"

[ -d "$WORKSPACE" ] || exit 0

# Guard: VM no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read Stop hook JSON from stdin
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "$$")

([ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]) && exit 0

# Count user messages for hard floor only
MSG_COUNT=$(jq -r 'select(.type == "user") | .type' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
[ "$MSG_COUNT" -lt 5 ] && exit 0

# Guard: skip unless significant work happened this session.
# MSG_COUNT is a poor proxy — 20 Q&A messages produce no useful record.
# Significance = files written/edited OR repos touched OR errors debugged.
init_state
WRITES=$(read_state '(.tools_used.Write // 0) + (.tools_used.Edit // 0) + (.tools_used.MultiEdit // 0)' 2>/dev/null || echo "0")
ERRORS=$(read_state '.errors_seen // 0' 2>/dev/null || echo "0")
REPOS=$(read_state '.repos_touched | length' 2>/dev/null || echo "0")
[ "${WRITES:-0}" -eq 0 ] && [ "${ERRORS:-0}" -eq 0 ] && [ "${REPOS:-0}" -eq 0 ] && exit 0

DATE=$(date -u +%Y-%m-%d)
DATETIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Extract recent turns (last 150 to keep Haiku call cheap)
TURNS=$(jq -r '
  select(.type == "user" or .type == "assistant") |
  if .type == "user" then
    "USER: " + (
      if (.message.content | type) == "string" then .message.content
      else ((.message.content // []) | map(select(.type == "text") | .text) | join(""))
      end | .[0:250]
    )
  else
    "ASSISTANT: " + (
      (.message.content // []) |
      map(
        if .type == "text" then .text
        elif .type == "tool_use" then "[" + .name + "]"
        else empty end
      ) |
      join(" ") | .[0:350]
    )
  end
' "$TRANSCRIPT" 2>/dev/null | tail -150)

[ -z "$TURNS" ] && exit 0

# Get git log for session period
SESSION_CWD=$(jq -r 'select(.type == "user" and .cwd != null) | .cwd' "$TRANSCRIPT" 2>/dev/null | head -1 || echo "$HOME")
[ -z "$SESSION_CWD" ] && SESSION_CWD="$HOME"
GIT_LOG=""
if GIT_ROOT=$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null); then
  GIT_LOG=$(git -C "$GIT_ROOT" log --oneline --since="6 hours ago" 2>/dev/null | head -10 || echo "")
fi

# Read enrichment from shared state
TOPIC=$(read_state '.retrieve.rooms_activated // [] | join(", ")' || echo "unknown")
REPOS=$(read_state '.repos_touched // [] | join(", ")' || echo "none")
TOOLS=$(read_state '.tools_used // {} | to_entries | map(.key + ":" + (.value|tostring)) | join(", ")' || echo "none")
ERRORS=$(read_state '.errors_seen // 0' || echo "0")
GOAL_STATUS=$(read_state '.goal_status // "n/a"' || echo "n/a")

# Tiered extraction:
#   Rich session (≥15 messages AND git commits exist) → call Haiku for structured summary
#   Thin session                                       → mechanical stub, no LLM call
if [ "$MSG_COUNT" -ge 15 ] && [ -n "$GIT_LOG" ]; then
  # Read prompt template
  if [ -f "$TEMPLATE_DIR/extract-summary.md" ]; then
    TEMPLATE=$(cat "$TEMPLATE_DIR/extract-summary.md")
  else
    TEMPLATE='Summarise this Claude Code session. Git: {{GIT_LOG}}. Transcript: {{TURNS}}. Output JSON: {"goal":"...","outcome":"...","project":"...","key_findings":[],"decisions_made":[],"what_worked":[],"what_didnt_work":[],"not_tried":[],"slug":"..."}'
  fi

  PROMPT_TEXT=$(echo "$TEMPLATE" | \
    sed "s|{{TOPIC}}|$TOPIC|g" | \
    sed "s|{{REPOS_TOUCHED}}|$REPOS|g" | \
    sed "s|{{TOOLS_USED}}|$TOOLS|g" | \
    sed "s|{{ERRORS_SEEN}}|$ERRORS|g" | \
    sed "s|{{GOAL_STATUS}}|$GOAL_STATUS|g")

  RAW_SUMMARY=$(printf '%s\n\nGit activity:\n%s\n\nTranscript:\n%s' \
    "$PROMPT_TEXT" "${GIT_LOG:-none}" "$TURNS" | \
    claude -p --model "$HAIKU_MODEL" --max-tokens 500 2>/dev/null || echo "")

  SUMMARY=$(echo "$RAW_SUMMARY" | jq -c '.' 2>/dev/null) || \
  SUMMARY=$(echo "$RAW_SUMMARY" | sed -n '/^```/,/^```/{//d;p}' | jq -c '.' 2>/dev/null) || \
  SUMMARY=""

  if [ -n "$SUMMARY" ]; then
    GOAL=$(echo "$SUMMARY" | jq -r '.goal // "Unknown goal"' 2>/dev/null | sed 's/"/\\"/g' || echo "Unknown goal")
    OUTCOME=$(echo "$SUMMARY" | jq -r '.outcome // ""' 2>/dev/null | sed 's/"/\\"/g' || echo "")
    PROJECT=$(echo "$SUMMARY" | jq -r '.project // "global"' 2>/dev/null | sed 's/"/\\"/g' || echo "global")
    SLUG=$(echo "$SUMMARY" | jq -r '.slug // "session"' 2>/dev/null | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
    FINDINGS=$(echo "$SUMMARY" | jq -r '.key_findings[]? | "- " + .' 2>/dev/null || echo "")
    DECISIONS=$(echo "$SUMMARY" | jq -r '.decisions_made[]? | "- " + .' 2>/dev/null || echo "")
    WORKED=$(echo "$SUMMARY" | jq -r '.what_worked[]? | "- " + .' 2>/dev/null || echo "")
    DIDNT_WORK=$(echo "$SUMMARY" | jq -r '.what_didnt_work[]? | "- " + .' 2>/dev/null || echo "")
    NOT_TRIED=$(echo "$SUMMARY" | jq -r '.not_tried[]? | "- " + .' 2>/dev/null || echo "")
  fi
fi

# Mechanical fallback — fill in from state if Haiku was skipped or failed
if [ -z "${GOAL:-}" ]; then
  SLUG=$(date +%H%M)-$(echo "${REPOS:-work}" | tr ', ' '-' | cut -c1-30)
  GOAL="Work session — repos: ${REPOS:-unknown}"
  OUTCOME="See git log below."
  PROJECT=$(echo "${TOPIC:-global}" | cut -d, -f1 | tr -d ' ')
  FINDINGS="Tools: ${TOOLS:-none}"
  DECISIONS="" WORKED="" DIDNT_WORK="" NOT_TRIED=""
fi

SESSION_DIR="$WORKSPACE/sessions/ai-sessions"
mkdir -p "$SESSION_DIR"
SESSION_FILE="$SESSION_DIR/${DATE}-${SLUG}.md"

cat > "$SESSION_FILE" << SESSIONEOF
---
date: ${DATE}
type: ai-session
project: "${PROJECT}"
goal: "${GOAL}"
outcome: "${OUTCOME}"
session_id: ${SESSION_ID}
---

# AI Session: ${GOAL}

**Date:** ${DATETIME}
**Project:** ${PROJECT}
**Outcome:** ${OUTCOME}

## Key Findings

${FINDINGS:-None recorded.}

## Decisions Made

${DECISIONS:-None recorded.}

## What Worked

${WORKED:-None recorded.}

## What Didn't Work

${DIDNT_WORK:-None recorded.}

## Not Yet Tried

${NOT_TRIED:-None recorded.}

## Git Activity

${GIT_LOG:-No git activity.}
SESSIONEOF

# Commit the session record
cd "$WORKSPACE"
git add "sessions/ai-sessions/${DATE}-${SLUG}.md" 2>/dev/null || true
git diff --cached --quiet 2>/dev/null || \
  git commit -m "session: ${DATE} — ${SLUG}" 2>/dev/null || true

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "persist-session" "wrote" "$ELAPSED" "\"file\":\"sessions/ai-sessions/${DATE}-${SLUG}.md\""

# ── Ghost note tail (L2 reflection) ──────────────────────────────────────────
# Gate: ≥5 ai-sessions, ≥2 distinct projects, 5-min cooldown
GHOST_COOLDOWN_FILE="/tmp/ghost-note-cooldown-${USER}"
SESSION_COUNT=$(ls -1 "${SESSION_DIR}"/*.md 2>/dev/null | wc -l | tr -d ' ')
mapfile -t _RECENT_FILES < <(ls -1t "${SESSION_DIR}"/*.md 2>/dev/null | head -10)
DISTINCT_PROJECTS=$(grep -h "^project:" "${_RECENT_FILES[@]}" 2>/dev/null | sort -u | wc -l | tr -d ' ')

if [ "${SESSION_COUNT:-0}" -ge 5 ] && [ "${DISTINCT_PROJECTS:-0}" -ge 2 ]; then
  LAST_GHOST=$(cat "$GHOST_COOLDOWN_FILE" 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  if [ $(( NOW_EPOCH - LAST_GHOST )) -ge 300 ]; then
    PRIOR_GHOSTS=$(grep "^> ghost:" "${_RECENT_FILES[@]}" 2>/dev/null | tail -5 || echo "")
    RECENT_CONTENT=$(cat "${_RECENT_FILES[@]}" 2>/dev/null | head -c 2000 || echo "")
    GHOST_LINE=$(printf 'Recent sessions (newest first):\n%s\n\nPrior ghost notes (do not repeat these):\n%s\n\nWrite exactly one new insight (≤25 words) about cross-session patterns. Output a single line starting with "> ghost:" and nothing else.' \
      "$RECENT_CONTENT" "$PRIOR_GHOSTS" | \
      claude -p --model "$HAIKU_MODEL" --max-tokens 220 2>/dev/null | \
      grep "^> ghost:" | head -1)
    if [ -n "$GHOST_LINE" ]; then
      printf '\n## Research Partner Notes\n\n%s\n' "$GHOST_LINE" >> "$SESSION_FILE"
      echo "$NOW_EPOCH" > "$GHOST_COOLDOWN_FILE"
      cd "$WORKSPACE"
      git add "sessions/ai-sessions/${DATE}-${SLUG}.md" 2>/dev/null || true
      git commit --amend --no-edit 2>/dev/null || true
      log_hook "persist-session" "ghost-note" "0" "\"ghost\":\"$(echo "$GHOST_LINE" | cut -c1-80)\""
    fi
  fi
fi
# ── end ghost note tail ───────────────────────────────────────────────────────

# ── L3 work poll ─────────────────────────────────────────────────────────────
# Physical host only (already guarded above: VM exits if goals.json exists).
# Poll workstation-api for any active work item VMs that have completed.
WORK_LIB="${HOME}/workspace/work/lib.sh"
if [ -f "$WORK_LIB" ]; then
  source "$WORK_LIB" 2>/dev/null || true
  work_poll 2>/dev/null || true
fi
# ── end L3 work poll ─────────────────────────────────────────────────────────

exit 0
