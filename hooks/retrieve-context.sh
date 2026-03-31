#!/usr/bin/env bash
# UserPromptSubmit hook — two-stage Haiku context retrieval from ICM workspace.
#
# Stage 1: tree + INDEX.md scan → which rooms are relevant?
# Stage 2: read CONTEXT.md for relevant rooms → summarize + list specific files.
# Output: summary paragraph + file pointers. Silent if nothing relevant.
#
# Physical host ONLY (VM agents have their own CONTEXT via goal/CLAUDE.md).
# Must complete in <5s total.

set -uo pipefail

WORKSPACE="${HOME}/workspace"
[ -d "$WORKSPACE" ] || exit 0

# Guard: VM no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -f "$WORKER_HOME/goals.json" ] && exit 0

# Read the submitted prompt from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
[ -z "$PROMPT" ] && exit 0

# Skip very short prompts (single words, commands)
WORD_COUNT=$(echo "$PROMPT" | wc -w)
[ "$WORD_COUNT" -lt 4 ] && exit 0

# --- Stage 1: Coarse scan ---
TREE=$(cd "$WORKSPACE" && tree -L 2 -I ".git|.gitkeep|.obsidian" --noreport 2>/dev/null || ls -1 "$WORKSPACE")

# Collect all INDEX.md paths (top-level rooms only for speed)
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

STAGE1=$(claude -p \
  --model claude-haiku-4-5-20251001 \
  --max-tokens 200 \
  "Task: ${PROMPT}

Workspace structure:
${TREE}

Room index files:
${INDEX_FILES}

Which rooms are relevant to this task? Output ONLY a space-separated list of folder paths (e.g. 'homelab dev/doable'), or output NONE if nothing is relevant. No explanation." 2>/dev/null || echo "NONE")

STAGE1=$(echo "$STAGE1" | tr '\n' ' ' | grep -oE '[a-z][a-z0-9/\-]*' | tr '\n' ' ' | xargs)
([ -z "$STAGE1" ] || [ "$STAGE1" = "NONE" ]) && exit 0

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

[ -z "$CONTEXT_CONTENT" ] && exit 0

STAGE2=$(claude -p \
  --model claude-haiku-4-5-20251001 \
  --max-tokens 300 \
  "Task: ${PROMPT}

Relevant room context:
${CONTEXT_CONTENT}

Write a 1-3 sentence summary of what context is relevant to this task.
Then list specific files in those rooms the agent should read if it needs more depth.
Format exactly:
SUMMARY: <sentences>
FILES: <space-separated relative paths from workspace root, or NONE>" 2>/dev/null || echo "")

[ -z "$STAGE2" ] && exit 0

# Only print if there's something worth saying
SUMMARY=$(echo "$STAGE2" | grep "^SUMMARY:" | sed 's/^SUMMARY: //')
FILES=$(echo "$STAGE2" | grep "^FILES:" | sed 's/^FILES: //')

[ -z "$SUMMARY" ] && exit 0
[ "$SUMMARY" = "NONE" ] && exit 0

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
