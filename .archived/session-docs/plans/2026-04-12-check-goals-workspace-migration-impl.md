# check-goals Workspace Migration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move the 4-phase goal loop logic out of `check-goals.sh` into `~/workspace/workflows/hooks/check-goals/run.sh`, leaving only a thin dispatcher in claude-code-skills.

**Architecture:** Same thin-dispatcher pattern as `agent-telemetry.sh`. The dispatcher exports `CLAUDE_SKILLS_LIB` so `run.sh` can source `lib/state.sh` and `lib/log.sh` from claude-code-skills. The dispatcher calls `bash "$RUN_SH"` (not `source`) to prevent set-option leakage. No behavior changes — pure lift-and-shift of logic.

**Tech Stack:** bash, jq (already present on all VMs and physical host)

---

### Task 1: Create workspace run.sh

**Files:**
- Create: `~/workspace/workflows/hooks/check-goals/run.sh`

**Step 1: Create the directory**

```bash
mkdir -p ~/workspace/workflows/hooks/check-goals
```

**Step 2: Write run.sh**

The content is the 4-phase logic from the current `check-goals.sh`, with two changes at the top:
1. Replace the `SCRIPT_DIR` / `source lib/` block with sourcing via `$CLAUDE_SKILLS_LIB`
2. Remove `init_state` — the dispatcher already called it before invoking bash run.sh

Create `~/workspace/workflows/hooks/check-goals/run.sh`:

```bash
#!/usr/bin/env bash
# check-goals/run.sh — Goal Loop Controller (4-phase)
# Sourced by ~/claude-code-skills/hooks/check-goals.sh (Stop hook dispatcher).
# VM-only: guards on goals.json existence.
#
# Phase 1: in_progress goal exists → block (resume it)
# Phase 2: pending goals exist → block (start next)
# Phase 3: unreviewed done goals → block with inline review instructions
#          (current Claude instance reviews via Bash tool — no subprocess)
# Phase 4: all reviewed, nothing pending → approve (Claude stops cleanly)
#
# Output: JSON {"decision": "block", "reason": "..."} or exit 0 to approve

source "${CLAUDE_SKILLS_LIB:-}/state.sh" 2>/dev/null || true
source "${CLAUDE_SKILLS_LIB:-}/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

GOALS_FILE="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}/goals.json"
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
REVIEW_START_FILE="/tmp/claude-worker-review-started-${CLAUDE_SESSION_ID:-$$}"
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
- Set reviewed_at to the current UTC timestamp (e.g., $(date -u +%Y-%m-%dT%H:%M:%SZ))
- If score < 9, append a new pending goal object describing the exact fix needed.

The next stop hook will automatically pick up any new pending fix goals."

emit_event "{\"type\":\"review_start\",\"count\":$UNREVIEWED_COUNT}"
update_state '.goal_status = "reviewing"' 2>/dev/null || true
ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-goals" "reviewing" "$ELAPSED" 2>/dev/null || true
jq -n --arg r "$REASON" '{"decision": "block", "reason": $r}'
exit 0
```

**Step 3: Make executable**

```bash
chmod +x ~/workspace/workflows/hooks/check-goals/run.sh
```

**Step 4: Verify the file exists and is executable**

```bash
ls -la ~/workspace/workflows/hooks/check-goals/run.sh
head -5 ~/workspace/workflows/hooks/check-goals/run.sh
```

Expected: file exists, first line is `#!/usr/bin/env bash`

**Step 5: Commit**

```bash
cd ~/workspace
git add workflows/hooks/check-goals/run.sh
git commit -m "feat(hooks): add check-goals/run.sh — migrate 4-phase goal loop from claude-code-skills"
```

---

### Task 2: Create CONTEXT.md for check-goals workflow

**Files:**
- Create: `~/workspace/workflows/hooks/check-goals/CONTEXT.md`

**Step 1: Write CONTEXT.md**

Create `~/workspace/workflows/hooks/check-goals/CONTEXT.md`:

```markdown
# check-goals

Stop hook workflow — goal loop controller for claude-worker VMs.
VM-only (guards on `goals.json` existence).

## Purpose

After each Claude session ends, inspect `goals.json` and decide whether
Claude should continue working or exit cleanly.

## The 4 Phases

| Phase | Condition | Action |
|-------|-----------|--------|
| 1 | An `in_progress` goal exists | Block — tell Claude to continue it |
| 2 | `pending` goals remain | Block — tell Claude to start the next one |
| 3 | `done` goals with no `reviewed_at` | Block — tell Claude to self-review and score |
| 4 | Nothing pending, all reviewed | Exit 0 — Claude stops cleanly |

Phase 3 has a **5-minute timeout**: if review takes longer than `REVIEW_TIMEOUT`
seconds, all unreviewed goals are auto-approved with score 5 and a note.

## Output format

- Block: JSON to stdout — `{"decision": "block", "reason": "..."}`
- Approve: exit 0 (no output)

## Environment variables

| Variable | Default | Source |
|----------|---------|--------|
| `CLAUDE_WORKER_HOME` | `/var/lib/claude-worker` | systemd env |
| `CLAUDE_WORKER_API` | `http://localhost:4200` | systemd env |
| `CLAUDE_SESSION_ID` | set by Claude Code | Claude env |
| `CLAUDE_SKILLS_LIB` | set by dispatcher | `check-goals.sh` |
| `REVIEW_TIMEOUT` | `300` (5 min) | hardcoded in run.sh |

## goals.json schema (relevant fields)

```json
[
  {
    "id": "uuid",
    "goal": "task description",
    "status": "pending | in_progress | done",
    "reviewed_at": "ISO8601 or null",
    "review_score": 0-10,
    "review_note": "string",
    "result": "string"
  }
]
```

## SSE events emitted

| Type | Phase | Payload |
|------|-------|---------|
| `goal_loop` | 1, 2 | `{type, phase, goal_id}` |
| `review_start` | 3 | `{type, count}` |
| `session_end` | 4 | `{type}` |
```

**Step 2: Commit**

```bash
cd ~/workspace
git add workflows/hooks/check-goals/CONTEXT.md
git commit -m "docs(hooks): add check-goals/CONTEXT.md — document 4-phase goal loop"
```

---

### Task 3: Replace check-goals.sh with thin dispatcher

**Files:**
- Modify: `~/claude-code-skills/hooks/check-goals.sh` (replace entirely)

**Step 1: Read the current file to confirm you're overwriting the right thing**

```bash
head -10 ~/claude-code-skills/hooks/check-goals.sh
```

Expected: lines mentioning "Phase 1", "Phase 2", "Goal Loop Controller"

**Step 2: Overwrite with the thin dispatcher**

Write `~/claude-code-skills/hooks/check-goals.sh`:

```bash
#!/usr/bin/env bash
# check-goals — Stop hook dispatcher
# Delegates all logic to ~/workspace/workflows/hooks/check-goals/run.sh.
# Fires first in the Stop chain; controls the goal loop for claude-worker VMs.

WORKSPACE="${WORKSPACE:-$HOME/workspace}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_SKILLS_LIB="$SCRIPT_DIR/lib"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true

RUN_SH="$WORKSPACE/workflows/hooks/check-goals/run.sh"

if [ ! -f "$RUN_SH" ]; then
  log_hook "check-goals" "skip-no-workflow" "0" 2>/dev/null || true
  exit 0
fi

bash "$RUN_SH"  # bash not source — prevents set option leakage into Stop chain
```

**Step 3: Make executable**

```bash
chmod +x ~/claude-code-skills/hooks/check-goals.sh
```

**Step 4: Verify line count (should be ~20 lines)**

```bash
wc -l ~/claude-code-skills/hooks/check-goals.sh
```

Expected: ~20 lines

**Step 5: Smoke test — physical host (no goals.json)**

On physical host, `goals.json` doesn't exist so the hook must exit 0 silently:

```bash
bash ~/claude-code-skills/hooks/check-goals.sh
echo "exit code: $?"
```

Expected: no output, exit code 0

**Step 6: Smoke test — simulate VM (with goals.json — all done + reviewed)**

```bash
export CLAUDE_WORKER_HOME=/tmp/test-worker-$$
mkdir -p "$CLAUDE_WORKER_HOME"
cat > "$CLAUDE_WORKER_HOME/goals.json" << 'EOF'
[
  {
    "id": "test-001",
    "goal": "test goal",
    "status": "done",
    "reviewed_at": "2026-04-12T00:00:00Z",
    "review_score": 9,
    "review_note": "done",
    "result": "completed"
  }
]
EOF
bash ~/claude-code-skills/hooks/check-goals.sh
echo "exit code: $?"
unset CLAUDE_WORKER_HOME
rm -rf /tmp/test-worker-$$
```

Expected: no output (Phase 4 clean exit), exit code 0

**Step 7: Smoke test — simulate pending goal**

```bash
export CLAUDE_WORKER_HOME=/tmp/test-worker-$$
mkdir -p "$CLAUDE_WORKER_HOME"
cat > "$CLAUDE_WORKER_HOME/goals.json" << 'EOF'
[
  {
    "id": "test-002",
    "goal": "implement feature X",
    "status": "pending",
    "reviewed_at": null,
    "review_score": null,
    "review_note": null,
    "result": null
  }
]
EOF
bash ~/claude-code-skills/hooks/check-goals.sh
echo "exit code: $?"
unset CLAUDE_WORKER_HOME
rm -rf /tmp/test-worker-$$
```

Expected: JSON output `{"decision":"block","reason":"1 pending goal(s) remain..."}`, exit code 0

**Step 8: Commit**

```bash
cd ~/claude-code-skills
git add hooks/check-goals.sh
git commit -m "refactor(hooks): check-goals.sh → thin dispatcher, logic moved to workspace"
```

---

### Task 4: Update workspace hooks CONTEXT.md

**Files:**
- Modify: `~/workspace/workflows/hooks/CONTEXT.md`

**Step 1: Read the current CONTEXT.md**

```bash
cat ~/workspace/workflows/hooks/CONTEXT.md
```

**Step 2: Add check-goals entry to the Prompt templates section**

In the `## Prompt templates` section, after the `### agent-telemetry` block, add:

```markdown
### check-goals
- [[check-goals/CONTEXT|check-goals]] — four-phase goal loop controller: resume in_progress, start pending, self-review done, clean exit (VM Stop hook only)
```

**Step 3: Commit**

```bash
cd ~/workspace
git add workflows/hooks/CONTEXT.md
git commit -m "docs(hooks): add check-goals to hooks CONTEXT.md index"
```

---

### Task 5: Push both repos

**Step 1: Push workspace**

```bash
cd ~/workspace
git push origin main
```

Expected: push succeeds

**Step 2: Push claude-code-skills**

```bash
cd ~/claude-code-skills
git push origin main
```

Expected: push succeeds

**Step 3: Verify both pushed**

```bash
cd ~/workspace && git log --oneline -3
cd ~/claude-code-skills && git log --oneline -3
```

Expected: the migration commits appear at the top of each log
