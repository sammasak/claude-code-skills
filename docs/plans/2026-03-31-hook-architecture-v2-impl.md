# Hook Architecture v2 — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade all 10 hooks with ICM prompt templates, shared session state, hook logging, smarter retrieval caching, Stop chain reorder, and quality gates on extract-instincts.

**Architecture:** Three new layers added to the existing script-per-hook model: (1) ICM prompt templates in `~/workspace/workflows/hooks/`, (2) shared session state in `/tmp/claude-hook-state-*.json` via `lib/state.sh`, (3) append-only hook log in `~/workspace/.hook-log/` via `lib/log.sh`. All Haiku prompts externalized to editable markdown.

**Tech Stack:** bash, jq, claude-haiku-4-5-20251001 (via `claude -p`), git, NixOS Home Manager (hook wiring via `mcp.nix`)

**Design doc:** `docs/plans/2026-03-31-hook-architecture-v2-design.md`

---

## Task 1: Create shared helper libraries

Foundation for all other tasks. Two files: `state.sh` (session state read/write) and `log.sh` (hook log append).

**Files:**
- Create: `~/claude-code-skills/hooks/lib/state.sh`
- Create: `~/claude-code-skills/hooks/lib/log.sh`

**Step 1: Create lib directory**

```bash
mkdir -p ~/claude-code-skills/hooks/lib
```

**Step 2: Write state.sh**

```bash
cat > ~/claude-code-skills/hooks/lib/state.sh << 'EOF'
#!/usr/bin/env bash
# Shared session state — read/write JSON file scoped to CLAUDE_SESSION_ID.
# Source this file from any hook: source "$(dirname "$0")/lib/state.sh"

STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"

init_state() {
  [ -f "$STATE_FILE" ] && return
  cat > "$STATE_FILE" << STATEEOF
{
  "session_id": "${CLAUDE_SESSION_ID:-$$}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prompt_count": 0,
  "retrieve": {
    "rooms_activated": [],
    "last_activated_at": null,
    "last_prompt_words": "",
    "context_injected": false
  },
  "repos_touched": [],
  "tools_used": {},
  "errors_seen": 0,
  "loop_count": 0,
  "goal_status": null
}
STATEEOF
}

read_state() {
  jq -r "$1" "$STATE_FILE" 2>/dev/null
}

update_state() {
  local tmp
  tmp=$(mktemp)
  if jq "$1" "$STATE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
  fi
}

inc_state() {
  update_state ".$1 = (.$1 // 0) + 1"
}
EOF
```

**Step 3: Write log.sh**

```bash
cat > ~/claude-code-skills/hooks/lib/log.sh << 'EOF'
#!/usr/bin/env bash
# Hook log — append-only JSONL for observability and cross-session intelligence.
# Source this file from any hook: source "$(dirname "$0")/lib/log.sh"

HOOK_LOG_DIR="${HOME}/workspace/.hook-log"

log_hook() {
  local hook="$1" result="$2" duration_ms="$3"
  shift 3

  [ -d "${HOME}/workspace" ] || return 0
  mkdir -p "$HOOK_LOG_DIR"

  local extra=""
  if [ $# -gt 0 ]; then
    extra=",$*"
  fi

  printf '{"ts":"%s","hook":"%s","session":"%s","duration_ms":%s,"result":"%s"%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$hook" \
    "${CLAUDE_SESSION_ID:-$$}" \
    "$duration_ms" \
    "$result" \
    "$extra" \
    >> "$HOOK_LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
}
EOF
```

**Step 4: Test state helpers**

```bash
export CLAUDE_SESSION_ID="test-lib-$$"
source ~/claude-code-skills/hooks/lib/state.sh
init_state
cat "$STATE_FILE" | jq .
read_state '.session_id'
update_state '.prompt_count = 5'
read_state '.prompt_count'
inc_state 'errors_seen'
read_state '.errors_seen'
rm "$STATE_FILE"
echo "state.sh OK"
```

Expected: session_id printed, prompt_count = 5, errors_seen = 1.

**Step 5: Test log helper**

```bash
source ~/claude-code-skills/hooks/lib/log.sh
log_hook "test" "ok" 42 '"foo":"bar"'
cat ~/workspace/.hook-log/$(date -u +%Y-%m-%d).jsonl | tail -1 | jq .
rm ~/workspace/.hook-log/$(date -u +%Y-%m-%d).jsonl
echo "log.sh OK"
```

Expected: JSON entry with hook=test, result=ok, duration_ms=42, foo=bar.

**Step 6: Commit**

```bash
cd ~/claude-code-skills
git add hooks/lib/state.sh hooks/lib/log.sh
git commit -m "feat: add shared hook libraries — state.sh and log.sh"
```

---

## Task 2: Create ICM prompt templates and update .gitignore

All Haiku prompts externalized to editable markdown in the workspace.

**Files:**
- Create: `~/workspace/workflows/hooks/INDEX.md`
- Create: `~/workspace/workflows/hooks/CONTEXT.md`
- Create: `~/workspace/workflows/hooks/retrieve-context/stage1-room-selection.md`
- Create: `~/workspace/workflows/hooks/retrieve-context/stage2-summarize.md`
- Create: `~/workspace/workflows/hooks/persist-session/extract-summary.md`
- Create: `~/workspace/workflows/hooks/extract-instincts/extract-learnings.md`
- Create: `~/workspace/workflows/hooks/write-session-state/handoff-document.md`
- Create: `~/workspace/workflows/hooks/validate-bash/alternatives.md`
- Modify: `~/workspace/.gitignore`

**Step 1: Create directory structure**

```bash
mkdir -p ~/workspace/workflows/hooks/retrieve-context
mkdir -p ~/workspace/workflows/hooks/persist-session
mkdir -p ~/workspace/workflows/hooks/extract-instincts
mkdir -p ~/workspace/workflows/hooks/write-session-state
mkdir -p ~/workspace/workflows/hooks/validate-bash
```

**Step 2: Write INDEX.md**

```bash
cat > ~/workspace/workflows/hooks/INDEX.md << 'EOF'
Load this room if: working on Claude Code hooks, improving retrieval quality, editing Haiku prompt templates, debugging hook behavior, hook architecture.
Skip if: using hooks normally (they load their own templates). Only enter this room when developing or maintaining hooks.
Key files: CONTEXT.md, retrieve-context/, persist-session/, extract-instincts/, validate-bash/
EOF
```

**Step 3: Write CONTEXT.md**

```bash
cat > ~/workspace/workflows/hooks/CONTEXT.md << 'EOF'
# Hook Prompt Templates

Editable Haiku prompts for Claude Code hooks. Each subdirectory contains prompt templates
for one hook. Templates use `{{VARIABLE}}` placeholders interpolated at runtime.

## How templates work

Hook scripts in `~/claude-code-skills/hooks/` read these files, replace `{{PLACEHOLDERS}}`
with runtime values, and pass the result to `claude -p --model claude-haiku-4-5-20251001`.

To improve a hook's behavior, edit the template here and commit. No code change needed.

## Template variables

| Variable | Source | Used in |
|----------|--------|---------|
| `{{PROMPT}}` | User's submitted prompt | retrieve-context stage 1+2 |
| `{{TREE}}` | `tree -L 2` of workspace | retrieve-context stage 1 |
| `{{INDEX_FILES}}` | Concatenated INDEX.md contents | retrieve-context stage 1 |
| `{{FREQUENT_ROOMS}}` | Hook log room frequency data | retrieve-context stage 1 |
| `{{CONTEXT_CONTENT}}` | Concatenated CONTEXT.md for activated rooms | retrieve-context stage 2 |
| `{{TURNS}}` | Recent transcript turns (text + tool names) | persist-session, extract-instincts, write-session-state |
| `{{GIT_LOG}}` | `git log --oneline --since="6 hours ago"` | persist-session |
| `{{TOPIC}}` | Session topic from shared state | persist-session |
| `{{REPOS_TOUCHED}}` | Repos worked in (from state) | persist-session |
| `{{TOOLS_USED}}` | Tool use counts (from state) | persist-session |
| `{{ERRORS_SEEN}}` | Error count (from state) | persist-session |
| `{{GOAL_STATUS}}` | Goal outcome (from state) | persist-session, write-session-state |
| `{{SCOPE}}` | Git remote-derived scope | extract-instincts |
| `{{RECENT_FILES}}` | Recently modified files | write-session-state |
| `{{GOALS_SUMMARY}}` | Goals list from goals.json | write-session-state |
EOF
```

**Step 4: Write retrieve-context templates**

```bash
cat > ~/workspace/workflows/hooks/retrieve-context/stage1-room-selection.md << 'EOF'
Task: {{PROMPT}}

Workspace structure:
{{TREE}}

Room index files:
{{INDEX_FILES}}

Recently relevant rooms (from prior sessions):
{{FREQUENT_ROOMS}}

Which rooms are relevant to this task? Output ONLY a space-separated list
of folder paths (e.g. 'homelab dev/doable'), or output NONE if nothing
is relevant. No explanation.
EOF

cat > ~/workspace/workflows/hooks/retrieve-context/stage2-summarize.md << 'EOF'
Task: {{PROMPT}}

Relevant room context:
{{CONTEXT_CONTENT}}

Write a 1-3 sentence summary of what context is relevant to this task.
Then list specific files in those rooms the agent should read if it needs more depth.
Format exactly:
SUMMARY: <sentences>
FILES: <space-separated relative paths from workspace root, or NONE>
EOF
```

**Step 5: Write persist-session template**

```bash
cat > ~/workspace/workflows/hooks/persist-session/extract-summary.md << 'EOF'
Summarise this Claude Code session for a knowledge vault record.

Session context:
- Topic: {{TOPIC}}
- Repos touched: {{REPOS_TOUCHED}}
- Tools used: {{TOOLS_USED}}
- Errors encountered: {{ERRORS_SEEN}}
- Goal status: {{GOAL_STATUS}}

Git activity (last 6h):
{{GIT_LOG}}

Session transcript (recent):
{{TURNS}}

Output JSON only:
{
  "goal": "one sentence",
  "outcome": "one sentence",
  "project": "project name or global",
  "key_findings": ["finding 1", "finding 2"],
  "decisions_made": ["decision 1"],
  "what_worked": ["approach 1"],
  "what_didnt_work": ["approach 2"],
  "not_tried": ["idea 1"],
  "slug": "short-kebab-case-topic"
}
EOF
```

**Step 6: Write extract-instincts template**

```bash
cat > ~/workspace/workflows/hooks/extract-instincts/extract-learnings.md << 'EOF'
Extract 0-3 atomic, reusable learnings from this session transcript.

Session transcript (recent):
{{TURNS}}

For each learning, output JSON:
{
  "learnings": [
    {
      "title": "short title",
      "content": "one paragraph of actionable advice",
      "scope": "{{SCOPE}}",
      "confidence": 4,
      "keywords": ["keyword1", "keyword2"]
    }
  ]
}

Rules:
- Only extract learnings that would help in FUTURE sessions (not session-specific facts)
- Confidence 1-5: 5 = definitely reusable across sessions, 1 = might be context-specific
- Skip entirely if nothing genuinely new was learned (output empty learnings array)
- Each learning must be actionable — "do X when Y" not "we did X"
EOF
```

**Step 7: Write write-session-state template**

```bash
cat > ~/workspace/workflows/hooks/write-session-state/handoff-document.md << 'EOF'
Write a structured session handoff for a knowledge vault.

Goal status: {{GOAL_STATUS}}
Goals summary: {{GOALS_SUMMARY}}
Recent git log: {{GIT_LOG}}
Recent files modified: {{RECENT_FILES}}

Session transcript (recent):
{{TURNS}}

Fill in each section (1-3 bullet points each). Output as markdown sections:

## What We Built
## What Worked
## What Did NOT Work
## What Hasn't Been Tried
## Open Questions
## Recommended Next Steps
EOF
```

**Step 8: Write validate-bash alternatives table**

```bash
cat > ~/workspace/workflows/hooks/validate-bash/alternatives.md << 'EOF'
| Blocked pattern | Suggested alternative |
|---|---|
| `git push --force` to main/master | `git push origin <branch>` or `git push --force-with-lease` to a feature branch |
| `sops -e` from /tmp | Copy file to repo path first: `cp /tmp/file.yaml path/in/repo/` then `sops -e --in-place path/in/repo/file.yaml` |
| `cargo build` without musl target (VM) | `cargo build --target x86_64-unknown-linux-musl` |
| `buildah push` without --authfile (VM) | `buildah push --authfile /var/lib/claude-worker/.config/containers/auth.json` |
EOF
```

**Step 9: Update .gitignore**

Add `.hook-log/` to `~/workspace/.gitignore`.

```bash
cd ~/workspace
echo ".hook-log/" >> .gitignore
```

**Step 10: Commit workspace changes**

```bash
cd ~/workspace
git add workflows/hooks/ .gitignore
git commit -m "feat: add ICM prompt templates for hook architecture v2"
git push
```

---

## Task 3: Rewrite retrieve-context.sh

Template-driven, cached, frequency-weighted retrieval with state and logging.

**Files:**
- Rewrite: `~/claude-code-skills/hooks/retrieve-context.sh`

**Step 1: Read current file**

```bash
cat ~/claude-code-skills/hooks/retrieve-context.sh
```

**Step 2: Write the new version**

Replace the full contents of `~/claude-code-skills/hooks/retrieve-context.sh` with:

```bash
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
```

**Step 3: Make executable and test**

```bash
chmod +x ~/claude-code-skills/hooks/retrieve-context.sh

# Test: should exit silently (short prompt)
echo '{"prompt": "ok"}' | CLAUDE_SESSION_ID="test-rc-$$" ~/claude-code-skills/hooks/retrieve-context.sh
echo "Exit: $?"

# Test: should produce signpost or exit silently (no workspace templates yet won't break — fallback inline prompts)
echo '{"prompt": "I need to debug the SOPS decryption on the cluster"}' | CLAUDE_SESSION_ID="test-rc-$$" ~/claude-code-skills/hooks/retrieve-context.sh
echo "Exit: $?"
```

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/retrieve-context.sh
git commit -m "feat: rewrite retrieve-context.sh — template-driven, cached, frequency-weighted"
```

---

## Task 4: Rewrite persist-session.sh

Template-driven, state-enriched, unified output format with proper YAML sanitization.

**Files:**
- Rewrite: `~/claude-code-skills/hooks/persist-session.sh`

**Step 1: Read current file**

```bash
cat ~/claude-code-skills/hooks/persist-session.sh
```

**Step 2: Write the new version**

Replace full contents of `~/claude-code-skills/hooks/persist-session.sh` with:

```bash
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

# Guard: minimum 8 external user messages
MSG_COUNT=$(jq -r 'select(.type == "user") | .type' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
[ "$MSG_COUNT" -lt 8 ] && exit 0

# Init state (may already exist from session)
init_state

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

# Read prompt template
if [ -f "$TEMPLATE_DIR/extract-summary.md" ]; then
  TEMPLATE=$(cat "$TEMPLATE_DIR/extract-summary.md")
else
  TEMPLATE='Summarise this Claude Code session. Git: {{GIT_LOG}}. Transcript: {{TURNS}}. Output JSON: {"goal":"...","outcome":"...","project":"...","key_findings":[],"decisions_made":[],"what_worked":[],"what_didnt_work":[],"not_tried":[],"slug":"..."}'
fi

# Build prompt with interpolated state values
PROMPT_TEXT=$(echo "$TEMPLATE" | \
  sed "s|{{TOPIC}}|$TOPIC|g" | \
  sed "s|{{REPOS_TOUCHED}}|$REPOS|g" | \
  sed "s|{{TOOLS_USED}}|$TOOLS|g" | \
  sed "s|{{ERRORS_SEEN}}|$ERRORS|g" | \
  sed "s|{{GOAL_STATUS}}|$GOAL_STATUS|g")

SUMMARY=$(printf '%s\n\nGit activity:\n%s\n\nTranscript:\n%s' \
  "$PROMPT_TEXT" "${GIT_LOG:-none}" "$TURNS" | \
  claude -p --model "$HAIKU_MODEL" --max-tokens 500 2>/dev/null || echo "")

[ -z "$SUMMARY" ] && exit 0

# Parse JSON fields with sanitization
GOAL=$(echo "$SUMMARY" | jq -r '.goal // "Unknown goal"' 2>/dev/null | sed 's/"/\\"/g' || echo "Unknown goal")
OUTCOME=$(echo "$SUMMARY" | jq -r '.outcome // ""' 2>/dev/null | sed 's/"/\\"/g' || echo "")
PROJECT=$(echo "$SUMMARY" | jq -r '.project // "global"' 2>/dev/null | sed 's/"/\\"/g' || echo "global")
SLUG=$(echo "$SUMMARY" | jq -r '.slug // "session"' 2>/dev/null | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
FINDINGS=$(echo "$SUMMARY" | jq -r '.key_findings[]? | "- " + .' 2>/dev/null || echo "")
DECISIONS=$(echo "$SUMMARY" | jq -r '.decisions_made[]? | "- " + .' 2>/dev/null || echo "")
WORKED=$(echo "$SUMMARY" | jq -r '.what_worked[]? | "- " + .' 2>/dev/null || echo "")
DIDNT_WORK=$(echo "$SUMMARY" | jq -r '.what_didnt_work[]? | "- " + .' 2>/dev/null || echo "")
NOT_TRIED=$(echo "$SUMMARY" | jq -r '.not_tried[]? | "- " + .' 2>/dev/null || echo "")

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

exit 0
```

**Step 3: Make executable and test**

```bash
chmod +x ~/claude-code-skills/hooks/persist-session.sh

# Test: empty transcript guard
echo '{"transcript_path": "", "session_id": "test"}' | CLAUDE_SESSION_ID="test-ps-$$" ~/claude-code-skills/hooks/persist-session.sh
echo "Exit: $?"
```

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/persist-session.sh
git commit -m "feat: rewrite persist-session.sh — template-driven, state-enriched, richer format"
```

---

## Task 5: Upgrade extract-instincts.sh

Add confidence gate, deduplication, expiry, template-driven extraction, and hook logging.

**Files:**
- Modify: `~/claude-code-skills/hooks/extract-instincts.sh`

**Step 1: Read current file**

```bash
cat ~/claude-code-skills/hooks/extract-instincts.sh
```

**Step 2: Apply changes**

The key modifications to the existing script:

1. Add `source lib/state.sh` and `source lib/log.sh` after the shebang
2. Read prompt template from `~/workspace/workflows/hooks/extract-instincts/extract-learnings.md` instead of inline heredoc
3. After Haiku returns JSON, filter by `.confidence >= 3`
4. Before writing each skill file, check keyword overlap with existing files in `~/.claude/skills/learned/$SCOPE/`
5. Add `# expires: YYYY-MM-DD` (30 days from now) to each written file
6. Add `# keywords: kw1,kw2,...` to each written file for dedup matching
7. Log to hook log at the end

The full rewrite should source the shared libraries, read the template, extract with confidence filtering, dedup, and log. Follow the same patterns as Tasks 3 and 4 (template reading, state sourcing, log_hook call).

The prompt template (`extract-learnings.md`) was already created in Task 2. The script should interpolate `{{TURNS}}` and `{{SCOPE}}` and pass to Haiku.

**Confidence gate:**

```bash
# After Haiku returns SUMMARY JSON:
LEARNINGS=$(echo "$SUMMARY" | jq -c '.learnings[]? | select(.confidence >= 3)' 2>/dev/null)
```

**Dedup check per learning:**

```bash
KEYWORDS=$(echo "$LEARNING" | jq -r '.keywords | join(",")')
SKIP=false
for existing in ~/.claude/skills/learned/"$SCOPE"/*.md; do
  [ -f "$existing" ] || continue
  EXISTING_KW=$(grep "^# keywords:" "$existing" 2>/dev/null | sed 's/^# keywords: //')
  [ -z "$EXISTING_KW" ] && continue
  MATCH=$(comm -12 <(echo "$KEYWORDS" | tr ',' '\n' | sort) <(echo "$EXISTING_KW" | tr ',' '\n' | sort) | wc -l)
  TOTAL=$(echo "$KEYWORDS" | tr ',' '\n' | wc -l)
  [ "$TOTAL" -gt 0 ] && [ $((MATCH * 100 / TOTAL)) -gt 70 ] && SKIP=true && break
done
```

**Expiry header in each file:**

```bash
EXPIRY_DATE=$(date -u -d "+30 days" +%Y-%m-%d 2>/dev/null || date -u -v+30d +%Y-%m-%d 2>/dev/null || echo "2026-04-30")
# Write at top of skill file:
echo "# expires: $EXPIRY_DATE"
echo "# keywords: $KEYWORDS"
```

**Step 3: Test**

```bash
echo '{"transcript_path": "", "session_id": "test"}' | CLAUDE_SESSION_ID="test-ei-$$" ~/claude-code-skills/hooks/extract-instincts.sh
echo "Exit: $?"
```

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/extract-instincts.sh
git commit -m "feat: upgrade extract-instincts.sh — confidence gate, dedup, expiry, template-driven"
```

---

## Task 6: Minor update to check-goals.sh

Write goal_status to shared state and log to hook log. Minimal changes.

**Files:**
- Modify: `~/claude-code-skills/hooks/check-goals.sh`

**Step 1: Read current file**

```bash
cat ~/claude-code-skills/hooks/check-goals.sh
```

**Step 2: Apply changes**

Add after the shebang/header:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))
```

Note: `2>/dev/null || true` because on physical hosts state.sh initializes fine but we don't want any failure in the sourcing to break goal processing.

At each exit point in Phase 1 (resume in_progress):

```bash
update_state '.goal_status = "in_progress"' 2>/dev/null || true
```

At each exit point in Phase 2 (pick pending):

```bash
update_state '.goal_status = "started"' 2>/dev/null || true
```

At Phase 3 completion (goal reviewed/approved):

```bash
update_state '.goal_status = "completed"' 2>/dev/null || true
```

At Phase 3 timeout (auto-approved):

```bash
update_state '.goal_status = "auto-approved"' 2>/dev/null || true
```

At the end of the script, before any exit:

```bash
ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
GOAL_STATUS=$(read_state '.goal_status // "none"' 2>/dev/null || echo "none")
log_hook "check-goals" "$GOAL_STATUS" "$ELAPSED" 2>/dev/null || true
```

**Step 3: Test**

```bash
# On physical host: should no-op (no goals.json)
echo '{}' | CLAUDE_SESSION_ID="test-cg-$$" ~/claude-code-skills/hooks/check-goals.sh
echo "Exit: $?"
```

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/check-goals.sh
git commit -m "feat: check-goals.sh writes goal_status to shared state + hook log"
```

---

## Task 7: Upgrade write-session-state.sh

Read goal_status from shared state, use prompt template, add hook logging.

**Files:**
- Modify: `~/claude-code-skills/hooks/write-session-state.sh`

**Step 1: Read current file, apply changes**

Add source lines for lib/state.sh and lib/log.sh. Read the handoff-document.md template. Interpolate `{{GOAL_STATUS}}`, `{{GOALS_SUMMARY}}`, `{{GIT_LOG}}`, `{{RECENT_FILES}}`, `{{TURNS}}`. Read `goal_status` from shared state (written by check-goals.sh which now fires before this hook). Log to hook log.

Follow the same patterns as Tasks 3-6.

**Step 2: Commit**

```bash
cd ~/claude-code-skills
git add hooks/write-session-state.sh
git commit -m "feat: write-session-state.sh reads goal_status from state, uses template"
```

---

## Task 8: Rewrite check-loop.sh

Fuzzy matching, failure-retry detection, escalation, state integration, hook logging.

**Files:**
- Rewrite: `~/claude-code-skills/hooks/check-loop.sh`

**Step 1: Read current file**

```bash
cat ~/claude-code-skills/hooks/check-loop.sh
```

**Step 2: Write the new version**

Key changes from v1:
- Source lib/state.sh and lib/log.sh
- Normalize commands before hashing: strip arguments that vary (paths, flags) to detect semantic loops
- Track exit codes alongside commands in state file
- Three escalation levels: 5 reps (warn), 8 (suggest stopping), 12 (recommend systematic-debugging)
- Write loop_count and errors_seen to shared state
- Log to hook log

**Fuzzy normalization:**

```bash
# Normalize command for fuzzy matching
NORMALIZED=$(echo "$CMD" | \
  sed 's|/[^ ]*||g' | \       # strip absolute paths
  sed 's/--[a-z-]*=[^ ]*//g' | \ # strip --flag=value
  tr -s ' ' | \
  xargs)
```

**Failure-retry detection:**

```bash
# Track last 3 exit codes alongside commands
# If same command failed 3 times → stronger warning
```

**Escalation thresholds:**

```bash
if [ "$COUNT" -ge 12 ]; then
  echo "⚠ Loop detected ($COUNT repetitions). Consider using /systematic-debugging to find root cause." >&2
elif [ "$COUNT" -ge 8 ]; then
  echo "⚠ Possible loop ($COUNT repetitions). Consider a different approach." >&2
elif [ "$COUNT" -ge 5 ]; then
  echo "⚠ Same command repeated $COUNT times." >&2
fi
```

**Step 3: Test**

```bash
# Simulate repeated command
for i in $(seq 1 6); do
  echo '{"tool_input":{"command":"cargo build"}}' | CLAUDE_SESSION_ID="test-cl-$$" ~/claude-code-skills/hooks/check-loop.sh
done
```

Expected: warning on 5th and 6th invocation.

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/check-loop.sh
git commit -m "feat: rewrite check-loop.sh — fuzzy matching, failure-retry, escalation"
```

---

## Task 9: Upgrade validate-bash.sh

Fix suggestions from template, state writes, hook logging.

**Files:**
- Modify: `~/claude-code-skills/hooks/validate-bash.sh`

**Step 1: Read current file, apply changes**

1. Source lib/state.sh and lib/log.sh
2. When blocking a command, read `~/workspace/workflows/hooks/validate-bash/alternatives.md` and find the matching row to include in the error message
3. Write `repos_touched` to shared state (detect from `git -C . remote get-url origin` in current dir)
4. Log every blocked command to hook log

**Alternative lookup:**

```bash
# Read alternatives table
ALT_FILE="$HOME/workspace/workflows/hooks/validate-bash/alternatives.md"
SUGGESTION=""
if [ -f "$ALT_FILE" ]; then
  SUGGESTION=$(grep -i "force.push" "$ALT_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)
fi
# Include in block message:
echo "BLOCKED: force push to main is not allowed.${SUGGESTION:+ Try: $SUGGESTION}" >&2
```

**Step 2: Commit**

```bash
cd ~/claude-code-skills
git add hooks/validate-bash.sh
git commit -m "feat: validate-bash.sh — fix suggestions from template, state + logging"
```

---

## Task 10: Upgrade validate-manifest.sh

Include securityContext boilerplate in warnings, add hook logging.

**Files:**
- Modify: `~/claude-code-skills/hooks/validate-manifest.sh`

**Step 1: Read current file, apply changes**

1. Source lib/log.sh
2. When warning about missing securityContext, include the boilerplate YAML to paste
3. Log to hook log

**Boilerplate output:**

```bash
echo "WARNING: Missing securityContext. Add to the container spec:"
echo "  securityContext:"
echo "    runAsNonRoot: true"
echo "    readOnlyRootFilesystem: true"
echo "    allowPrivilegeEscalation: false"
```

**Step 2: Commit**

```bash
cd ~/claude-code-skills
git add hooks/validate-manifest.sh
git commit -m "feat: validate-manifest.sh — boilerplate suggestions, hook logging"
```

---

## Task 11: Upgrade validate-rust.sh

First-error-only output, state writes, hook logging.

**Files:**
- Modify: `~/claude-code-skills/hooks/validate-rust.sh`

**Step 1: Read current file, apply changes**

1. Source lib/state.sh and lib/log.sh
2. On cargo check failure, emit only the first error (not the full wall):

```bash
ERRORS=$(cargo check --quiet --manifest-path "$CARGO_TOML" 2>&1)
if [ $? -ne 0 ]; then
  FIRST_ERROR=$(echo "$ERRORS" | grep "^error" | head -1)
  echo "Cargo check failed: $FIRST_ERROR"
  echo "Run \`cargo check\` for full output."
  inc_state 'errors_seen'
fi
```

3. Log to hook log

**Step 2: Commit**

```bash
cd ~/claude-code-skills
git add hooks/validate-rust.sh
git commit -m "feat: validate-rust.sh — first-error-only output, state + logging"
```

---

## Task 12: Upgrade report-activity.sh

Physical host logging mode.

**Files:**
- Modify: `~/claude-code-skills/hooks/report-activity.sh`

**Step 1: Read current file, apply changes**

After the VM guard (`[ -d "$WORKER_HOME" ] || exit 0`), replace the `exit 0` with a physical-host logging path:

```bash
# Physical host: log to hook log, no API call
if [ ! -d "$WORKER_HOME" ]; then
  source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || exit 0
  source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || exit 0
  init_state 2>/dev/null || true
  # Increment tool count in state
  update_state ".tools_used.\"$TOOL_NAME\" = ((.tools_used.\"$TOOL_NAME\" // 0) + 1)" 2>/dev/null || true
  log_hook "activity" "$MESSAGE" 0 "\"tool\":\"$TOOL_NAME\"" 2>/dev/null || true
  exit 0
fi
```

The VM path remains unchanged.

**Step 2: Commit**

```bash
cd ~/claude-code-skills
git add hooks/report-activity.sh
git commit -m "feat: report-activity.sh — physical host logging mode, tool counts in state"
```

---

## Task 13: Reorder Stop chain in mcp.nix

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`

**Step 1: Read current file**

```bash
cat ~/nixos-config/modules/programs/cli/claude-code/mcp.nix
```

**Step 2: Reorder Stop hooks**

Change the Stop block from:

```nix
Stop = [{
  hooks = [
    { type = "command"; command = "${skillsSrc}/hooks/check-goals.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/persist-session.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/extract-instincts.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/write-session-state.sh"; }
  ];
}];
```

To:

```nix
Stop = [{
  hooks = [
    { type = "command"; command = "${skillsSrc}/hooks/persist-session.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/extract-instincts.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/check-goals.sh"; }
    { type = "command"; command = "${skillsSrc}/hooks/write-session-state.sh"; }
  ];
}];
```

**Step 3: Commit**

```bash
cd ~/nixos-config
git add modules/programs/cli/claude-code/mcp.nix
git commit -m "feat: reorder Stop chain — persist and extract before check-goals blocks"
```

---

## Task 14: Push, update flake, build, and verify

**Step 1: Push claude-code-skills**

```bash
cd ~/claude-code-skills
git push
```

**Step 2: Update flake input in nixos-config**

```bash
cd ~/nixos-config
nix flake update claude-code-skills
```

**Step 3: Build and verify**

```bash
cd ~/nixos-config
nix build .#nixosConfigurations.lenovo.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.acer-swift.config.system.build.toplevel --no-link
```

**Step 4: Commit flake.lock**

```bash
cd ~/nixos-config
git add flake.lock
git commit -m "chore: update claude-code-skills — hook architecture v2"
git push
```

**Step 5: Rebuild (lenovo — current host)**

```bash
sudo nixos-rebuild switch --flake .#lenovo
```

**Step 6: Verify hooks are wired**

```bash
cat ~/.claude/settings.json | jq '.hooks | keys'
# Expected: ["PostToolUse", "PreToolUse", "Stop", "UserPromptSubmit"]

cat ~/.claude/settings.json | jq '.hooks.Stop[0].hooks | map(.command | split("/") | last)'
# Expected: ["persist-session.sh", "extract-instincts.sh", "check-goals.sh", "write-session-state.sh"]
```

**Step 7: Copy lenovo closure to acer-swift for later activation**

```bash
LENOVO_CLOSURE=$(nix build .#nixosConfigurations.acer-swift.config.system.build.toplevel --no-link --print-out-paths)
nix copy --no-check-sigs --to ssh://lukas@acer-swift "$LENOVO_CLOSURE" 2>/dev/null || echo "Copy to acer-swift — run rebuild there later"
```

---

## Verification Checklist

After all tasks complete:

- [ ] `ls ~/claude-code-skills/hooks/lib/` shows `state.sh` and `log.sh`
- [ ] `ls ~/workspace/workflows/hooks/` shows `INDEX.md`, `CONTEXT.md`, and 5 subdirectories
- [ ] Hook log directory exists: `ls ~/workspace/.hook-log/` (may be empty until first hook fires)
- [ ] `.hook-log/` is in `~/workspace/.gitignore`
- [ ] `cat ~/.claude/settings.json | jq '.hooks.Stop[0].hooks | length'` returns `4`
- [ ] Stop chain order: persist-session → extract-instincts → check-goals → write-session-state
- [ ] Manual test: `echo '{"prompt": "ok"}' | CLAUDE_SESSION_ID=test ~/claude-code-skills/hooks/retrieve-context.sh` — exits silently
- [ ] Manual test: `echo '{"prompt": "debug the SOPS issue on the cluster"}' | CLAUDE_SESSION_ID=test ~/claude-code-skills/hooks/retrieve-context.sh` — shows signpost or exits silently
- [ ] Hook log entry created after retrieval test: `cat ~/workspace/.hook-log/$(date +%Y-%m-%d).jsonl | jq .`
- [ ] State file created: `cat /tmp/claude-hook-state-test.json | jq .`
- [ ] All hooks have `chmod +x`
