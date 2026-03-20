#!/usr/bin/env bash
# Stop hook — extract atomic learnings from this session and write them
# as injectable SKILL.md files to ~/.claude/skills/learned/<scope>/.
#
# Physical host ONLY (guard: exits immediately on VMs).
# Requires >=15 user messages in the transcript.
# Fires AFTER check-goals.sh in the Stop hook chain.
# Uses claude-haiku for cheap extraction.

set -euo pipefail

# Guard: VM no-op (claude-worker VMs have goals.json, physical host does not)
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read Stop hook JSON from stdin
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "$$")

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Guard: minimum 15 user messages
MSG_COUNT=$(grep -c '"type":"user"' "$TRANSCRIPT" 2>/dev/null || echo "0")
[ "$MSG_COUNT" -lt 15 ] && exit 0

# Determine scope from git remote of the session's working directory
SESSION_CWD=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT" 2>/dev/null | head -1 || echo "")
[ -z "$SESSION_CWD" ] && SESSION_CWD="$HOME"

GIT_ROOT=$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$GIT_ROOT" ]; then
  REMOTE=$(git -C "$GIT_ROOT" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE" ]; then
    # git@github.com:user/repo.git → repo
    SCOPE=$(echo "$REMOTE" | sed 's|.*[:/]\([^/]*\)\.git$|\1|; s|.*[:/]\([^/]*\)$|\1|')
  else
    SCOPE=$(basename "$GIT_ROOT")
  fi
else
  SCOPE="global"
fi
# Sanitize scope: lowercase, alphanumeric+hyphens only
SCOPE=$(echo "$SCOPE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')

LEARNED_DIR="$HOME/.claude/skills/learned/${SCOPE}"
mkdir -p "$LEARNED_DIR"

# Extract last 200 relevant turns from transcript (capped to control cost)
TURNS=$(jq -r '
  select(.type == "user" or .type == "assistant") |
  if .type == "user" then
    "USER: " + (
      if (.message.content | type) == "string" then .message.content
      else ((.message.content // []) | map(select(.type == "text") | .text) | join(""))
      end | .[0:300]
    )
  else
    "ASSISTANT: " + (
      (.message.content // []) |
      map(select(.type == "text") | .text) |
      join("") | .[0:400]
    )
  end
' "$TRANSCRIPT" 2>/dev/null | tail -200)

[ -z "$TURNS" ] && exit 0

# Call claude-haiku to extract 0-3 atomic learnings
EXTRACTION=$(claude -p \
  --model claude-haiku-4-5-20251001 \
  "You are reviewing a Claude Code session transcript. Extract 0-3 atomic learnings that are:
- Specific to the project/codebase being worked on (scope: $SCOPE)
- Actionable (trigger + action, not general advice)
- Worth remembering in future sessions

Output ONLY a JSON array. Each item: {\"title\": \"short title\", \"body\": \"one paragraph with specific details\"}
If nothing is worth extracting, output: []

TRANSCRIPT:
$TURNS" 2>/dev/null || echo "[]")

# Parse and write each learning as a SKILL.md
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SHORT_DATE=$(date -u +%Y%m%d)

echo "$EXTRACTION" | jq -c '.[]' 2>/dev/null | while IFS= read -r entry; do
  TITLE=$(echo "$entry" | jq -r '.title // ""')
  BODY=$(echo "$entry" | jq -r '.body // ""')
  [ -z "$TITLE" ] || [ -z "$BODY" ] && continue

  SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
  SKILL_FILE="$LEARNED_DIR/${SHORT_DATE}-${SLUG}.md"
  DESCRIPTION=$(echo "$BODY" | head -1 | cut -c1-120)
  NAME="learned-${SCOPE}-${SLUG}"

  cat > "$SKILL_FILE" << SKILLEOF
---
name: ${NAME}
description: "${DESCRIPTION}"
injectable: true
learned: true
learned_at: "${DATE}"
scope: "${SCOPE}"
---

# ${TITLE}

${BODY}
SKILLEOF

done

exit 0
