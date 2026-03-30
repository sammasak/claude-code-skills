#!/usr/bin/env bash
# Stop hook — write AI session record to ~/workspace/sessions/ai-sessions/.
#
# Physical host ONLY. Fires after check-goals.sh.
# Requires transcript + at least one modified file or meaningful message count.
# Uses claude-haiku to extract: goal, outcome, key findings, decisions, files modified.

set -euo pipefail

WORKSPACE="${HOME}/workspace"
[ -d "$WORKSPACE" ] || exit 0

# Guard: VM no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read Stop hook JSON from stdin
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "$$")

([ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]) && exit 0

# Guard: minimum 8 user messages (meaningful session)
MSG_COUNT=$(jq -r 'select(.type == "user") | .type' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
[ "$MSG_COUNT" -lt 8 ] && exit 0

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
      map(select(.type == "text") | .text) |
      join("") | .[0:350]
    )
  end
' "$TRANSCRIPT" 2>/dev/null | tail -150)

[ -z "$TURNS" ] && exit 0

# Get git diff summary for context
SESSION_CWD=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT" 2>/dev/null | head -1 || echo "$HOME")
GIT_SUMMARY=""
if GIT_ROOT=$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null); then
  GIT_SUMMARY=$(git -C "$GIT_ROOT" diff --stat HEAD 2>/dev/null | tail -5 || echo "")
fi

# Call Haiku to extract session summary
SUMMARY=$(claude -p \
  --model claude-haiku-4-5-20251001 \
  --max-tokens 400 \
  "Summarise this Claude Code session for a knowledge vault record.

Git changes:
${GIT_SUMMARY:-none}

Session transcript (recent):
${TURNS}

Output JSON only:
{
  \"goal\": \"one sentence\",
  \"outcome\": \"one sentence\",
  \"project\": \"project name or global\",
  \"key_findings\": [\"finding 1\", \"finding 2\"],
  \"decisions_made\": [\"decision 1\"],
  \"slug\": \"short-kebab-case-topic\"
}" 2>/dev/null || echo "")

[ -z "$SUMMARY" ] && exit 0

GOAL=$(echo "$SUMMARY" | jq -r '.goal // "Unknown goal"' 2>/dev/null || echo "Unknown goal")
OUTCOME=$(echo "$SUMMARY" | jq -r '.outcome // ""' 2>/dev/null || echo "")
PROJECT=$(echo "$SUMMARY" | jq -r '.project // "global"' 2>/dev/null || echo "global")
SLUG=$(echo "$SUMMARY" | jq -r '.slug // "session"' 2>/dev/null | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
FINDINGS=$(echo "$SUMMARY" | jq -r '.key_findings[]? | "- " + .' 2>/dev/null || echo "")
DECISIONS=$(echo "$SUMMARY" | jq -r '.decisions_made[]? | "- " + .' 2>/dev/null || echo "")

SESSION_DIR="$WORKSPACE/sessions/ai-sessions"
mkdir -p "$SESSION_DIR"

SESSION_FILE="$SESSION_DIR/${DATE}-${SLUG}.md"

cat > "$SESSION_FILE" << SESSIONEOF
---
date: ${DATE}
type: ai-session
project: ${PROJECT}
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

## Git Changes

${GIT_SUMMARY:-No git changes.}
SESSIONEOF

# Commit the session record
cd "$WORKSPACE"
git add "sessions/ai-sessions/${DATE}-${SLUG}.md" 2>/dev/null || true
git diff --cached --quiet 2>/dev/null || \
  git commit -m "session: ${DATE} — ${SLUG}" 2>/dev/null || true

exit 0
