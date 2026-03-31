#!/usr/bin/env bash
# UserPromptSubmit hook — two-stage Haiku context retrieval from ICM workspace.
#
# Stage 1: tree + INDEX.md scan → which rooms are relevant?
# Stage 2: read CONTEXT.md for relevant rooms → summarize + list specific files.
# Output: summary paragraph + file pointers. Silent if nothing relevant.
#
# Physical host ONLY (VM agents have their own CONTEXT via goal/CLAUDE.md).
# Uses prompt templates from ~/workspace/workflows/hooks/retrieve-context/.
# Session cache: skips re-retrieval if topic hasn't shifted.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/log.sh"

START_MS=$(($(date +%s%N) / 1000000))

WORKSPACE="${HOME}/workspace"
HAIKU_MODEL="claude-haiku-4-5-20251001"
TEMPLATE_DIR="$WORKSPACE/workflows/hooks/retrieve-context"

[ -d "$WORKSPACE" ] || exit 0

# Guard: VM no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read the submitted prompt from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
[ -z "$PROMPT" ] && exit 0

# Skip very short prompts
WORD_COUNT=$(echo "$PROMPT" | wc -w)
[ "$WORD_COUNT" -lt 4 ] && exit 0

# Init shared state
init_state
update_state '.prompt_count = (.prompt_count + 1)'

# --- Session cache: skip if topic hasn't shifted ---
LAST_WORDS=$(read_state '.retrieve.last_prompt_words // ""')
if [ -n "$LAST_WORDS" ]; then
  OVERLAP=$(comm -12 \
    <(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u) \
    <(echo "$LAST_WORDS" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u) \
    | wc -l)
  TOTAL=$(echo "$PROMPT" | wc -w)
  if [ "$TOTAL" -gt 0 ]; then
    RATIO=$((OVERLAP * 100 / TOTAL))
    if [ "$RATIO" -gt 60 ]; then
      log_hook "retrieve-context" "cached" 0 "\"prompt_words\":$WORD_COUNT"
      exit 0
    fi
  fi
fi

# --- Stage 1: Coarse scan ---
TREE=$(cd "$WORKSPACE" && tree -L 2 -I ".git|.gitkeep|.obsidian|.hook-log" --noreport 2>/dev/null || find "$WORKSPACE" -maxdepth 2 -type d -not -path '*/.git/*' | sed "s|$WORKSPACE/||" | sort)

# Collect all INDEX.md files
INDEX_FILES=""
for f in "$WORKSPACE"/*/INDEX.md "$WORKSPACE"/*/*/INDEX.md; do
  [ -f "$f" ] || continue
  REL="${f#$WORKSPACE/}"
  CONTENT=$(cat "$f")
  INDEX_FILES="${INDEX_FILES}
=== ${REL} ===
${CONTENT}"
done

[ -z "$INDEX_FILES" ] && exit 0

# Cross-session frequency hints from hook log
FREQUENT_ROOMS="(none)"
if [ -d "$HOOK_LOG_DIR" ]; then
  FREQ=$(cat "$HOOK_LOG_DIR"/*.jsonl 2>/dev/null | \
    jq -r 'select(.hook == "retrieve-context" and .rooms_activated != null) | .rooms_activated[]' 2>/dev/null | \
    sort | uniq -c | sort -rn | head -5 | awk '{print $2 " (" $1 " sessions)"}' 2>/dev/null || echo "")
  [ -n "$FREQ" ] && FREQUENT_ROOMS="$FREQ"
fi

# Read Stage 1 prompt template
if [ -f "$TEMPLATE_DIR/stage1-room-selection.md" ]; then
  STAGE1_TEMPLATE=$(cat "$TEMPLATE_DIR/stage1-room-selection.md")
else
  STAGE1_TEMPLATE='Task: {{PROMPT}}

Workspace structure:
{{TREE}}

Room index files:
{{INDEX_FILES}}

Which rooms are relevant? Output ONLY space-separated folder paths or NONE.'
fi

# Interpolate template
STAGE1_PROMPT=$(echo "$STAGE1_TEMPLATE" | \
  sed "s|{{PROMPT}}|$PROMPT|g" | \
  sed "s|{{FREQUENT_ROOMS}}|$FREQUENT_ROOMS|g")
# TREE and INDEX_FILES contain newlines/special chars — use heredoc for claude
STAGE1=$(printf '%s\n\nWorkspace structure:\n%s\n\nRoom index files:\n%s' \
  "$STAGE1_PROMPT" "$TREE" "$INDEX_FILES" | \
  claude -p --model "$HAIKU_MODEL" --max-tokens 200 2>/dev/null || echo "NONE")

STAGE1=$(echo "$STAGE1" | tr '\n' ' ' | grep -oE '[a-z][a-z0-9/\-]*' | tr '\n' ' ' | xargs)
([ -z "$STAGE1" ] || [ "$STAGE1" = "NONE" ]) && {
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "retrieve-context" "none" "$ELAPSED" "\"prompt_words\":$WORD_COUNT"
  exit 0
}

# --- Stage 2: Targeted read ---
CONTEXT_CONTENT=""
for ROOM in $STAGE1; do
  CTX_FILE="$WORKSPACE/$ROOM/CONTEXT.md"
  IDX_FILE="$WORKSPACE/$ROOM/INDEX.md"
  if [ -f "$CTX_FILE" ]; then
    CONTENT=$(head -60 "$CTX_FILE")
    CONTEXT_CONTENT="${CONTEXT_CONTENT}
=== ${ROOM}/CONTEXT.md ===
${CONTENT}"
  elif [ -f "$IDX_FILE" ]; then
    CONTENT=$(cat "$IDX_FILE")
    CONTEXT_CONTENT="${CONTEXT_CONTENT}
=== ${ROOM}/INDEX.md ===
${CONTENT}"
  fi
done

[ -z "$CONTEXT_CONTENT" ] && {
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "retrieve-context" "no-context" "$ELAPSED" "\"rooms\":\"$STAGE1\""
  exit 0
}

# Read Stage 2 prompt template
if [ -f "$TEMPLATE_DIR/stage2-summarize.md" ]; then
  STAGE2_TEMPLATE=$(cat "$TEMPLATE_DIR/stage2-summarize.md")
else
  STAGE2_TEMPLATE='Task: {{PROMPT}}

Relevant room context:
{{CONTEXT_CONTENT}}

Write 1-3 sentence summary. Then list specific files.
Format:
SUMMARY: <sentences>
FILES: <space-separated paths or NONE>'
fi

STAGE2=$(printf '%s\n\nRelevant room context:\n%s' \
  "$(echo "$STAGE2_TEMPLATE" | sed "s|{{PROMPT}}|$PROMPT|g")" \
  "$CONTEXT_CONTENT" | \
  claude -p --model "$HAIKU_MODEL" --max-tokens 300 2>/dev/null || echo "")

[ -z "$STAGE2" ] && exit 0

SUMMARY=$(echo "$STAGE2" | grep "^SUMMARY:" | sed 's/^SUMMARY: //')
FILES=$(echo "$STAGE2" | grep "^FILES:" | sed 's/^FILES: //')

[ -z "$SUMMARY" ] && exit 0
[ "$SUMMARY" = "NONE" ] && exit 0

# Update shared state
ROOMS_JSON=$(echo "$STAGE1" | tr ' ' '\n' | jq -R . | jq -s .)
update_state ".retrieve.rooms_activated = $ROOMS_JSON | .retrieve.last_prompt_words = \"$(echo "$PROMPT" | tr '"' "'" | cut -c1-200)\" | .retrieve.last_activated_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" | .retrieve.context_injected = true"

# Log
ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
ROOMS_LOG=$(echo "$ROOMS_JSON" | jq -c .)
log_hook "retrieve-context" "signpost" "$ELAPSED" "\"prompt_words\":$WORD_COUNT,\"rooms_activated\":$ROOMS_LOG"

# Output signpost
echo ""
echo "── WORKSPACE CONTEXT ──────────────────────────────────────"
echo "$SUMMARY"
if [ -n "$FILES" ] && [ "$FILES" != "NONE" ]; then
  echo ""
  echo "Read if needed:"
  for F in $FILES; do
    echo "  ~/workspace/$F"
  done
fi
echo "────────────────────────────────────────────────────────────"
echo ""

exit 0
