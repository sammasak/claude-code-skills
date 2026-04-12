#!/usr/bin/env bash
# Stop hook — extract atomic learnings from this session and write them
# as injectable SKILL.md files to ~/.claude/skills/learned/<scope>/.
#
# Physical host ONLY (guard: exits immediately on VMs).
# Requires >=15 user messages in the transcript.
# Fires BEFORE check-goals.sh in the Stop hook chain.
# Uses claude-haiku for cheap extraction.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/log.sh"
START_MS=$(($(date +%s%N) / 1000000))

# Guard: VM no-op (claude-worker VMs have goals.json, physical host does not)
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read Stop hook JSON from stdin
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "$$")

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then exit 0; fi

# Count user messages for hard floor only
MSG_COUNT=$(grep -c '"type":"user"' "$TRANSCRIPT" 2>/dev/null || echo "0")
[ "$MSG_COUNT" -lt 8 ] && exit 0

# Guard: skip unless files were written/edited or repos were touched.
# Pure Q&A and read-only exploration sessions don't produce extractable learnings.
WRITES=$(read_state '(.tools_used.Write // 0) + (.tools_used.Edit // 0) + (.tools_used.MultiEdit // 0)' 2>/dev/null || echo "0")
REPOS=$(read_state '.repos_touched | length' 2>/dev/null || echo "0")
[ "${WRITES:-0}" -eq 0 ] && [ "${REPOS:-0}" -eq 0 ] && exit 0

# --- Frequency Capping: Only extract if significant new messages since last run ---
# Use MSG_COUNT as a proxy for 'prompt' to trigger on volume shift
if ! check_frequency "extract-instincts" 300 "$MSG_COUNT"; then
  exit 0
fi

# Determine scope from git remote of the session's working directory
SESSION_CWD=$(jq -r 'select(.cwd != null) | .cwd' "$TRANSCRIPT" 2>/dev/null | head -1 || echo "")
[ -z "$SESSION_CWD" ] && SESSION_CWD="$HOME"

GIT_ROOT=$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$GIT_ROOT" ]; then
  # Try to extract repo name from remote origin URL
  REMOTE=$(git -C "$GIT_ROOT" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE" ]; then
    # Handle git@github.com:user/repo.git or https://github.com/user/repo.git
    SCOPE=$(echo "$REMOTE" | sed -E 's/.*[\/:]//; s/\.git$//')
  fi
  # Fallback to directory name if remote name is empty or unknown
  if [ -z "${SCOPE:-}" ] || [ "$SCOPE" = "origin" ]; then
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

# Load prompt template (external file with inline fallback)
TEMPLATE_DIR="$HOME/workspace/workflows/hooks/extract-instincts"
if [ -f "$TEMPLATE_DIR/extract-learnings.md" ]; then
  TEMPLATE=$(cat "$TEMPLATE_DIR/extract-learnings.md")
else
  TEMPLATE='Extract 0-3 atomic, reusable learnings. Transcript: {{TURNS}}. Output JSON: {"learnings":[{"title":"...","content":"...","scope":"{{SCOPE}}","confidence":4,"keywords":["kw1"]}]}'
fi

# Substitute template variables
PROMPT=$(echo "$TEMPLATE" | sed "s|{{SCOPE}}|$SCOPE|g")
PROMPT="${PROMPT//\{\{TURNS\}\}/$TURNS}"

# Call claude-haiku to extract 0-3 atomic learnings
RAW=$(claude -p \
  --model claude-haiku-4-5-20251001 \
  "$PROMPT" 2>/dev/null || echo '{"learnings":[]}')

# Extract JSON — claude -p may wrap response in markdown fences or explanatory text
EXTRACTION=$(echo "$RAW" | jq -c '.' 2>/dev/null) || \
EXTRACTION=$(echo "$RAW" | sed -n '/^```/,/^```/{//d;p}' | jq -c '.' 2>/dev/null) || \
EXTRACTION='{"learnings":[]}'

# Filter by confidence >= 3
LEARNINGS=$(echo "$EXTRACTION" | jq -c '.learnings[]? | select(.confidence >= 3)' 2>/dev/null || echo "")

# Parse and write each learning as a SKILL.md
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SHORT_DATE=$(date -u +%Y%m%d)
EXPIRY_DATE=$(date -u -d "+30 days" +%Y-%m-%d 2>/dev/null || date -u -v+30d +%Y-%m-%d 2>/dev/null || echo "2026-04-30")
WRITTEN_COUNT=0

while IFS= read -r entry; do
  [ -z "$entry" ] && continue

  TITLE=$(echo "$entry" | jq -r '.title // ""')
  BODY=$(echo "$entry" | jq -r '.content // ""')
  KEYWORDS=$(echo "$entry" | jq -r '.keywords | join(",")' 2>/dev/null || echo "")
  [ -z "$TITLE" ] || [ -z "$BODY" ] && continue

  # Dedup: skip if >70% keyword overlap with existing files
  SKIP=false
  for existing in "$LEARNED_DIR"/*.md; do
    [ -f "$existing" ] || continue
    EXISTING_KW=$(grep "^# keywords:" "$existing" 2>/dev/null | sed 's/^# keywords: //')
    [ -z "$EXISTING_KW" ] && continue
    MATCH=$(comm -12 <(echo "$KEYWORDS" | tr ',' '\n' | sort) <(echo "$EXISTING_KW" | tr ',' '\n' | sort) | wc -l)
    TOTAL=$(echo "$KEYWORDS" | tr ',' '\n' | wc -l)
    [ "$TOTAL" -gt 0 ] && [ $((MATCH * 100 / TOTAL)) -gt 70 ] && SKIP=true && break
  done
  "$SKIP" && continue

  SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
  SKILL_FILE="$LEARNED_DIR/${SHORT_DATE}-${SLUG}.md"
  DESCRIPTION=$(echo "$BODY" | head -1 | cut -c1-120)
  NAME="learned-${SCOPE}-${SLUG}"

  cat > "$SKILL_FILE" << SKILLEOF
# expires: ${EXPIRY_DATE}
# keywords: ${KEYWORDS}
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

  WRITTEN_COUNT=$((WRITTEN_COUNT + 1))
done <<< "$LEARNINGS"

RESULT="ok"
ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "extract-instincts" "$RESULT" "$ELAPSED" "\"learnings_written\":${WRITTEN_COUNT:-0}"

exit 0
