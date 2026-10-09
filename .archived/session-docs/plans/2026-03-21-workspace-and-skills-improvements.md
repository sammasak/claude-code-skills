# Workspace & Skills Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 4 structural bugs in the ICM workspace, add 3 new hooks (instinct extraction, VM session state, Rust validation), update workstation-api CLAUDE.md, and scaffold the workspace eval framework.

**Architecture:** Five independent workstreams executed in sequence. Workspace fixes are first (blocking). Hooks go into claude-code-skills and are wired via mcp.nix in nixos-config. Evals extend the existing runner/solving pattern with a new runner/workspace sub-package. All commits are small and scoped.

**Tech Stack:** Bash (hooks), Nix (mcp.nix wiring), Python/pydantic-evals (eval runner), Markdown (workspace files, CLAUDE.md).

---

## WORKSTREAM 1 — ICM Workspace Structural Fixes

### Task 1: Fix CLAUDE.md routing table (workflow rows → gateway)

**Files:**
- Modify: `~/workspace/CLAUDE.md`

Currently lines 19-21 route directly to sub-workflow CONTEXT.md files, bypassing `workflows/CONTEXT.md` and its "stop on failure" rules. Fix by routing all three workflow rows to `workflows/CONTEXT.md` instead.

**Step 1: Edit the three workflow routing rows**

Open `~/workspace/CLAUDE.md`. Change lines 19–21 from:

```
| Deploy a service | `workflows/deploy-service/CONTEXT.md` | container-workflows, credentials, kubernetes-gitops, verify-service |
| Provision a claude-worker VM | `workflows/provision-vm/CONTEXT.md` | claude-ctl |
| Release NixOS config | `workflows/release-nixos/CONTEXT.md` | nix-flake-development |
```

To:

```
| Deploy a service | `workflows/CONTEXT.md` | container-workflows, credentials, kubernetes-gitops, verify-service |
| Provision a claude-worker VM | `workflows/CONTEXT.md` | claude-ctl |
| Release NixOS config | `workflows/CONTEXT.md` | nix-flake-development |
```

**Step 2: Add cross-room sequencing rule**

Append to the `## Rules` section (after line 46):

```
- Some tasks span rooms — if a task involves both development and deployment, complete the dev room work first, then run the deploy-service workflow
```

**Step 3: Verify the file looks correct**

```bash
cat ~/workspace/CLAUDE.md
```

Expected: three workflow rows all point to `workflows/CONTEXT.md`, Rules section has 5 bullets.

**Step 4: Commit**

```bash
cd ~/workspace
git add CLAUDE.md
git commit -m "fix: route workflow rows through workflows/CONTEXT.md gateway"
```

---

### Task 2: Fix workflows/CONTEXT.md (remove circular step, add dispatch)

**Files:**
- Modify: `~/workspace/workflows/CONTEXT.md`

Currently Step 1 says "Read CLAUDE.md to confirm this is the right workflow" — a circular re-read. The file also needs to become the gateway that dispatches to specific workflow sub-folders.

**Step 1: Rewrite the "How to run a workflow" section**

Replace:

```markdown
## How to run a workflow

1. Read CLAUDE.md to confirm this is the right workflow
2. Read the workflow's CONTEXT.md — it defines what inputs it needs and what each stage does
3. Work through each stage in order
4. Each stage has a clear output — verify it before moving to the next stage
```

With:

```markdown
## How to run a workflow

1. Read the specific workflow CONTEXT.md for your task (see Available workflows table above)
2. Check what inputs the workflow needs before starting
3. Work through each stage in order
4. Each stage has a clear output — verify it before moving to the next stage
```

**Step 2: Verify**

```bash
cat ~/workspace/workflows/CONTEXT.md
```

Expected: Step 1 now says "Read the specific workflow CONTEXT.md", no mention of CLAUDE.md.

**Step 3: Commit**

```bash
cd ~/workspace
git add workflows/CONTEXT.md
git commit -m "fix: remove circular CLAUDE.md re-read from workflow gateway"
```

---

### Task 3: Fix deploy-service — add service dispatch table, label doable-only stages

**Files:**
- Modify: `~/workspace/workflows/deploy-service/CONTEXT.md`

The workstation-api short-circuit ("skip Stages 2 and 3") is buried in line 38 inside a code block. Add a dispatch table before Stage 1 and label doable-only stages.

**Step 1: Add service execution path table after Registry paths section**

After the `## Registry paths` table (after line 19), insert:

```markdown
## Service execution path

| Service | Stages to run |
|---------|---------------|
| doable | 1 → 2 → 3 → 4 |
| workstation-api | 1 → 4 (`just release` handles build + push internally) |
```

**Step 2: Label Stage 2 and Stage 3 as doable-only**

Change `## Stage 2: Push` to `## Stage 2: Push (doable only)`

Change `## Stage 3: Apply` — NOTE: this stage applies to BOTH services (kubectl rollout restart). Keep heading as `## Stage 3: Apply` but add a note inside: "workstation-api: this step is handled by `just release` — skip to Stage 4."

**Step 3: Remove the buried short-circuit note from Stage 1**

Delete line 38:
```
Note: `just release` for workstation-api handles compile + build + push in one step — skip Stages 2 and 3 and go directly to Stage 4 (Verify).
```

This information is now in the dispatch table. Remove the duplicate.

**Step 4: Verify the file structure**

```bash
cat ~/workspace/workflows/deploy-service/CONTEXT.md
```

Expected: Service execution path table present before Stage 1, Stage 2 heading says "(doable only)", buried note gone.

**Step 5: Commit**

```bash
cd ~/workspace
git add workflows/deploy-service/CONTEXT.md
git commit -m "fix: add service dispatch table, label doable-only stages in deploy-service"
```

---

### Task 4: Fix dev/CONTEXT.md — add /tmp/doable recovery note

**Files:**
- Modify: `~/workspace/dev/CONTEXT.md`

`/tmp/doable` is ephemeral and won't survive a reboot. Add a recovery note.

**Step 1: Add recovery note under doable specifics**

After line 27 (`- Dev server: npm run dev...`), insert:

```
- If `/tmp/doable` does not exist (e.g. after reboot), ask for the clone URL or check git remote in the project
```

**Step 2: Commit**

```bash
cd ~/workspace
git add dev/CONTEXT.md
git commit -m "fix: add /tmp/doable non-persistence recovery note"
```

---

### Task 5: Push workspace fixes

**Step 1: Push all 4 fix commits**

```bash
cd ~/workspace
git push origin main
git log --oneline -5
```

Expected: 4 fix commits on top of the existing history.

---

## WORKSTREAM 2 — Three New Hooks

### Task 6: Create validate-rust.sh (PostToolUse Rust validation)

**Files:**
- Create: `~/claude-code-skills/hooks/validate-rust.sh`

**Step 1: Write the hook**

```bash
#!/usr/bin/env bash
# PostToolUse Write|Edit hook — Rust file validator
# After any Write or Edit to a .rs file, find the Cargo workspace root
# and run cargo check --quiet, surfacing compile errors as feedback to Claude.
# Never blocks (PostToolUse cannot block). Only fires inside a Cargo workspace.

set -euo pipefail

FILE=$(echo "${CLAUDE_TOOL_INPUT:-{\}}" | jq -r '.file_path // ""' 2>/dev/null || echo "")

# Only for .rs files
case "$FILE" in
  *.rs) ;;
  *) exit 0 ;;
esac

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Walk up directory tree to find Cargo.toml (workspace root)
DIR=$(dirname "$FILE")
CARGO_ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/Cargo.toml" ]; then
    CARGO_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

# No Cargo workspace found — stray .rs file, skip
[ -z "$CARGO_ROOT" ] && exit 0

# Find cargo binary (rustup managed)
CARGO=""
if command -v cargo >/dev/null 2>&1; then
  CARGO=$(command -v cargo)
elif [ -x "$HOME/.cargo/bin/cargo" ]; then
  CARGO="$HOME/.cargo/bin/cargo"
else
  exit 0
fi

# Run cargo check — quiet suppresses Compiling lines, leaving only errors
OUTPUT=$("$CARGO" check --quiet --manifest-path "$CARGO_ROOT/Cargo.toml" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ cargo check passed: $(basename "$FILE")"
else
  echo "cargo check FAILED after editing $FILE:"
  echo "$OUTPUT"
  echo ""
  echo "Fix the compile errors above before continuing."
fi

exit 0
```

**Step 2: Make executable**

```bash
chmod +x ~/claude-code-skills/hooks/validate-rust.sh
```

**Step 3: Test it manually against workstation-api**

```bash
# Simulate what the hook receives
export CLAUDE_TOOL_INPUT='{"file_path": "/home/lukas/workstation-api/src/handlers.rs"}'
bash ~/claude-code-skills/hooks/validate-rust.sh
```

Expected: `✓ cargo check passed: handlers.rs` (or compile errors if any exist)

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/validate-rust.sh
git commit -m "feat: add validate-rust.sh PostToolUse hook for cargo check on .rs edits"
```

---

### Task 7: Create extract-instincts.sh (Stop hook — physical host only)

**Files:**
- Create: `~/claude-code-skills/hooks/extract-instincts.sh`

**Step 1: Write the hook**

```bash
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
```

**Step 2: Make executable**

```bash
chmod +x ~/claude-code-skills/hooks/extract-instincts.sh
```

**Step 3: Smoke test the guard logic (should exit 0 silently on a VM)**

```bash
# Simulate VM environment
CLAUDE_WORKER_HOME=/var/lib/claude-worker \
  bash -c 'touch /tmp/test-goals.json; ln -sf /tmp/test-goals.json /var/lib/claude-worker/goals.json 2>/dev/null; echo "{}" | bash ~/claude-code-skills/hooks/extract-instincts.sh; echo "exit: $?"'
```

Expected: exits 0 silently (guard fires immediately).

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add hooks/extract-instincts.sh
git commit -m "feat: add extract-instincts.sh Stop hook for self-improving skill library"
```

---

### Task 8: Create write-session-state.sh (Stop hook — VM only)

**Files:**
- Create: `~/claude-code-skills/hooks/write-session-state.sh`

**Step 1: Write the hook**

```bash
#!/usr/bin/env bash
# Stop hook — write structured session state file at goal completion.
# VM ONLY (guard: no-ops on physical host where goals.json is absent).
# Fires AFTER check-goals.sh and extract-instincts.sh.
# Only writes when all goals are done+reviewed (no active goals remaining).

set -euo pipefail

# Guard: physical host no-op
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
GOALS_FILE="$WORKER_HOME/goals.json"
[ ! -f "$GOALS_FILE" ] && exit 0

# Only write when truly stopping (no pending/in_progress goals)
ACTIVE=$(jq '[.[] | select(.status == "pending" or .status == "in_progress")] | length' \
  "$GOALS_FILE" 2>/dev/null || echo "1")
[ "$ACTIVE" -gt 0 ] && exit 0

# Find most recently completed goal
LAST_GOAL=$(jq -c '[.[] | select(.status == "done")] | sort_by(.completed_at) | last' \
  "$GOALS_FILE" 2>/dev/null || echo "null")
[ -z "$LAST_GOAL" ] || [ "$LAST_GOAL" = "null" ] && exit 0

GOAL_ID=$(echo "$LAST_GOAL" | jq -r '.id')
GOAL_TEXT=$(echo "$LAST_GOAL" | jq -r '.goal')
GOAL_RESULT=$(echo "$LAST_GOAL" | jq -r '.result // "No result recorded"')

# Prepare sessions directory
SESSIONS_DIR="$WORKER_HOME/workspace/.claude/sessions"
mkdir -p "$SESSIONS_DIR"

DATE=$(date -u +%Y-%m-%d)
SHORT_ID="${GOAL_ID:0:8}"
STATE_FILE="$SESSIONS_DIR/${DATE}-${SHORT_ID}.md"

# Collect mechanical state (git log + recent files)
GIT_LOG=""
if git -C "$WORKER_HOME/workspace" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_LOG=$(git -C "$WORKER_HOME/workspace" log --oneline -10 2>/dev/null || echo "no commits")
fi

RECENT_FILES=$(find "$WORKER_HOME/workspace" -newer "$GOALS_FILE" -type f \
  -not -path "*/node_modules/*" -not -path "*/.git/*" \
  2>/dev/null | head -20 | sed "s|$WORKER_HOME/workspace/||" || echo "none")

# Write header + mechanical section immediately
cat > "$STATE_FILE" << STATEEOF
# Session State — Goal ${GOAL_ID}
**Date:** ${DATE}
**Goal:** ${GOAL_TEXT}
**Result:** ${GOAL_RESULT}

## 5. Current File State

### Recent Git Commits
${GIT_LOG:-No git repository or no commits}

### Recently Modified Files
${RECENT_FILES}

---
STATEEOF

# Read transcript for LLM extraction
INPUT=$(cat /dev/stdin 2>/dev/null || echo "{}")
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  ASSISTANT_TURNS=$(jq -r '
    select(.type == "assistant") |
    (.message.content // []) |
    map(select(.type == "text") | .text) |
    join("") | .[0:800]
  ' "$TRANSCRIPT" 2>/dev/null | tail -60)

  if [ -n "$ASSISTANT_TURNS" ]; then
    EXTRACTION=$(claude -p \
      --model claude-haiku-4-5-20251001 \
      "Fill in these sections for a session handoff document. Be specific and terse.
Goal was: $GOAL_TEXT
Transcript excerpt: $ASSISTANT_TURNS

Output ONLY the following sections (use ## headers exactly):
## 1. What We Built
## 2. What Worked
## 3. What Did NOT Work
## 4. What Hasn't Been Tried
## 6. Decisions Made
## 7. Blockers
## 8. Exact Next Step" 2>/dev/null || echo "")

    [ -n "$EXTRACTION" ] && echo "$EXTRACTION" >> "$STATE_FILE"
  fi
fi

exit 0
```

**Step 2: Make executable**

```bash
chmod +x ~/claude-code-skills/hooks/write-session-state.sh
```

**Step 3: Commit**

```bash
cd ~/claude-code-skills
git add hooks/write-session-state.sh
git commit -m "feat: add write-session-state.sh Stop hook for VM goal handoff"
```

---

### Task 9: Update check-goals.sh Phase 2 — append session state hint

**Files:**
- Modify: `~/claude-code-skills/hooks/check-goals.sh` (line 51)

Add session state file path to the Phase 2 block message so the next invocation knows to read it.

**Step 1: Add session state lookup before the Phase 2 jq call**

Find the Phase 2 block (around line 46-53). Before the `jq -n` call, add:

```bash
  SESSION_NOTE=""
  SESSION_FILE=$(ls -t "${WORKER_HOME}/workspace/.claude/sessions/"*.md 2>/dev/null | head -1 || echo "")
  [ -n "$SESSION_FILE" ] && SESSION_NOTE=" Prior session state at: $SESSION_FILE — read it before starting."
```

Then modify the jq block reason from:

```bash
  jq -n --arg r "$PENDING pending goal(s) remain. Next goal: id=$NEXT_ID goal=\"$NEXT_DESC\". Mark it in_progress with jq and work on it." \
    '{"decision": "block", "reason": $r}'
```

To:

```bash
  jq -n --arg r "$PENDING pending goal(s) remain. Next goal: id=$NEXT_ID goal=\"$NEXT_DESC\". Mark it in_progress with jq and work on it.${SESSION_NOTE}" \
    '{"decision": "block", "reason": $r}'
```

**Step 2: Verify syntax**

```bash
bash -n ~/claude-code-skills/hooks/check-goals.sh
```

Expected: no errors (bash syntax check passes).

**Step 3: Commit**

```bash
cd ~/claude-code-skills
git add hooks/check-goals.sh
git commit -m "feat: append session state file hint to check-goals.sh Phase 2 block message"
```

---

### Task 10: Wire all three new hooks in mcp.nix

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`

**Step 1: Add extract-instincts.sh and write-session-state.sh to Stop hooks**

Find the current Stop hooks section:

```nix
Stop = [{
  hooks = [{
    type = "command";
    command = "${skillsSrc}/hooks/check-goals.sh";
  }];
}];
```

Replace with:

```nix
Stop = [{
  hooks = [
    {
      type = "command";
      command = "${skillsSrc}/hooks/check-goals.sh";
    }
    {
      type = "command";
      command = "${skillsSrc}/hooks/extract-instincts.sh";
    }
    {
      type = "command";
      command = "${skillsSrc}/hooks/write-session-state.sh";
    }
  ];
}];
```

**Step 2: Add validate-rust.sh to PostToolUse hooks**

Find the current PostToolUse section:

```nix
PostToolUse = [{
  matcher = "Write|Edit";
  hooks = [{
    type = "command";
    command = "${skillsSrc}/hooks/validate-manifest.sh";
  }];
}];
```

Replace with:

```nix
PostToolUse = [{
  matcher = "Write|Edit";
  hooks = [
    {
      type = "command";
      command = "${skillsSrc}/hooks/validate-manifest.sh";
    }
    {
      type = "command";
      command = "${skillsSrc}/hooks/validate-rust.sh";
    }
  ];
}];
```

**Step 3: Validate Nix syntax**

```bash
nix-instantiate --parse ~/nixos-config/modules/programs/cli/claude-code/mcp.nix > /dev/null
```

Expected: no errors.

**Step 4: Commit**

```bash
cd ~/nixos-config
git add modules/programs/cli/claude-code/mcp.nix
git commit -m "feat: wire extract-instincts, write-session-state, validate-rust hooks in mcp.nix"
```

**Step 5: Rebuild to apply**

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#$(hostname)
```

Expected: rebuild succeeds, new hooks present at `~/.claude/hooks/`.

```bash
ls -la ~/.claude/hooks/
```

Expected: `extract-instincts.sh`, `write-session-state.sh`, `validate-rust.sh` all symlinked.

---

## WORKSTREAM 3 — Update workstation-api CLAUDE.md

### Task 11: Update workstation-api/CLAUDE.md with missing content

**Files:**
- Modify: `~/workstation-api/CLAUDE.md`

CLAUDE.md already exists (437 lines) but is missing: pool function signatures, `spawn_immediate_goal_post`, `repoUrl`/`display_goal` feature, new CRD spec fields, new metrics, and the correct `just release` command.

**Step 1: Add missing pool function signatures**

Find the pool section in CLAUDE.md and add the public function signatures that are called cross-module:

```markdown
### pool.rs — Public API

| Function | Signature | What it does |
|----------|-----------|-------------|
| `find_available_pool_vm` | `async fn find_available_pool_vm(client, namespace) -> Option<WorkspaceClaim>` | Lists WCs with `spec.pool=true` and `status.phase=Ready`, returns first available |
| `claim_pool_vm` | `async fn claim_pool_vm(client, namespace, name, goal, repo_url, bootstrap) -> Result<WorkspaceClaim>` | PATCHes pool=false + goal onto VM, handles 409 race |
| `post_goal_to_vm` | `async fn post_goal_to_vm(ip, goal) -> Result<()>` | POST to `http://{ip}:4200/goals` (claude-worker HTTP API) |
| `patch_goal_posted` | `async fn patch_goal_posted(client, namespace, name) -> Result<()>` | PATCHes `status.goalPosted=true` |
```

**Step 2: Add `repoUrl` and `display_goal` to CRD spec table**

Find the `WorkspaceClaimSpec` fields table and add:

```
| `repo_url` | `Option<String>` | GitHub URL; when set, goal is prepended with a `git clone` preamble |
| `goal` | `Option<String>` | Seeded to agent goal queue (includes clone preamble if repo_url set) |
| `pool` | `bool` | When true: VM is a warm pool VM, invisible to normal API consumers |
| `preview_url` | `Option<String>` | Live preview URL shown in doable UI |
```

**Step 3: Add `spawn_immediate_goal_post` documentation**

Add a section on the immediate goal posting pattern:

```markdown
### Immediate Goal Posting (create_workspace)

When `create_workspace` adopts a pool VM, it calls `spawn_immediate_goal_post(client, namespace, name, ip, goal)` — a detached Tokio task (`tokio::spawn`) that POSTs the goal directly to the VM's claude-worker API at `http://{ip}:4200/goals`. This bypasses the controller's `post_goal_if_needed()` for faster goal delivery on pool VMs that are already Running.

The goal text is built by `build_goal_payload(goal, repo_url)` which prepends a `git clone <repo_url>` step when repo_url is set. `extract_display_goal(goal, repo_url)` strips the preamble for display in API responses.
```

**Step 4: Fix the just commands table**

Find any reference to `just push` and correct it to `just release` (which is an alias for `just publish`). The correct commands are:

```markdown
| `just release [tag]` | Build musl binary → buildah build → skopeo copy to registry (alias for `just publish`) |
| `just publish [tag]` | Same as above — buildah + skopeo push to `registry.sammasak.dev/workstations/workstation-api` |
```

**Step 5: Add missing metrics to the metrics table**

Add:
```
| `pool_ready_vms` | gauge | Current count of pool VMs in Ready state |
| `pool_claim_attempts_total{result}` | counter | result: success/conflict/error |
| `vmi_lookup_duration_seconds` | histogram | Time to query KubeVirt VMI |
| `goal_post_duration_seconds` | histogram | Time to POST goal to claude-worker |
```

**Step 6: Add `WorkspaceResponse` new fields**

Add to the response type documentation:
```
| `goal_posted` | `Option<bool>` | Whether goal has been successfully posted to claude-worker |
| `goal_posting_error` | `Option<String>` | Error message if goal posting failed |
| `repo_url` | `Option<String>` | Repo URL from spec |
| `display_goal` | `Option<String>` | Goal text with clone preamble stripped |
```

**Step 7: Verify the file is valid markdown**

```bash
wc -l ~/workstation-api/CLAUDE.md
```

Expected: line count increased from 437.

**Step 8: Commit**

```bash
cd ~/workstation-api
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with pool functions, repoUrl, display_goal, correct just commands"
```

---

## WORKSTREAM 4 — Workspace Eval Framework

### Task 12: Create eval directory structure for workspace

**Files:**
- Create: `~/claude-code-skills/evals/workspace/` (directory tree)

**Step 1: Create the directory structure**

```bash
mkdir -p ~/claude-code-skills/evals/workspace/routing
mkdir -p ~/claude-code-skills/evals/workspace/deploy-service/task-doable
mkdir -p ~/claude-code-skills/evals/workspace/deploy-service/task-workstation-api
mkdir -p ~/claude-code-skills/evals/workspace/provision-vm/task-with-goal
mkdir -p ~/claude-code-skills/evals/workspace/provision-vm/task-without-goal
mkdir -p ~/claude-code-skills/evals/workspace/release-nixos/task-local
```

**Step 2: Create routing/trigger.yaml**

```yaml
skill: workspace-routing

positives:
  - "Deploy the doable UI service"
  - "Ship the latest workstation-api build"
  - "Provision a new claude-worker VM for a goal"
  - "Release my NixOS config changes to the homelab"
  - "Build a new feature in the doable frontend"
  - "Add a new API endpoint to workstation-api"
  - "Fix the stuck HelmRelease in monitoring namespace"
  - "Add a SOPS secret to the cluster"

hard_negatives:
  - "Write a Python script to parse logs"     # -> local/ not dev/
  - "Rebuild the lenovo NixOS host"           # -> homelab/ not workflow
  - "Encrypt a new secret with SOPS"          # -> homelab/ not deploy workflow

true_negatives:
  - "What is a HelmRelease?"
  - "Explain Flux GitOps"
  - "Help me understand SOPS encryption"
```

**Step 3: Commit the structure**

```bash
cd ~/claude-code-skills
git add evals/workspace/
git commit -m "feat: scaffold workspace eval directory structure and routing trigger.yaml"
```

---

### Task 13: Write deploy-service eval tasks (doable + workstation-api)

**Files:**
- Create: `evals/workspace/deploy-service/task-doable/instruction.md`
- Create: `evals/workspace/deploy-service/task-doable/test.sh`
- Create: `evals/workspace/deploy-service/task-workstation-api/instruction.md`
- Create: `evals/workspace/deploy-service/task-workstation-api/test.sh`

**Step 1: Write doable instruction.md**

```markdown
# Deploy the doable UI Service

You are working in the ~/workspace ICM workspace. CLAUDE.md has been read and you have been routed to workflows/deploy-service/CONTEXT.md (contents provided as your system context).

## Task

Deploy the doable SvelteKit UI service. The source is at `/tmp/doable`. The target registry image is `registry.sammasak.dev/lab/doable-ui:latest`. The Kubernetes namespace is `doable`.

Produce a deployment plan at `/tmp/eval-output/plan.md` that covers all required stages with the exact commands for each stage and a verification step per stage.
```

**Step 2: Write doable test.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/plan.md"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: plan.md not found at $OUTPUT"
    exit 1
fi

# Stage 1: npm run build must precede buildah
if ! grep -q "npm run build" "$OUTPUT"; then
    echo "FAIL: Stage 1 must include 'npm run build' for doable"
    exit 1
fi

if ! grep -q "buildah build" "$OUTPUT"; then
    echo "FAIL: Stage 1 must include 'buildah build'"
    exit 1
fi

if ! grep -q "\-\-isolation=chroot" "$OUTPUT"; then
    echo "FAIL: buildah build must use --isolation=chroot"
    exit 1
fi

# Stage 2: buildah push with authfile
if ! grep -q "buildah push" "$OUTPUT"; then
    echo "FAIL: Stage 2 must include 'buildah push' for doable"
    exit 1
fi

if ! grep -q "\-\-authfile" "$OUTPUT"; then
    echo "FAIL: buildah push must use --authfile (not hardcoded credentials)"
    exit 1
fi

# Stage ordering: push must precede kubectl rollout
PUSH_LINE=$(grep -n "buildah push" "$OUTPUT" | head -1 | cut -d: -f1)
ROLLOUT_LINE=$(grep -n "kubectl rollout" "$OUTPUT" | head -1 | cut -d: -f1)

if [[ -z "$PUSH_LINE" || -z "$ROLLOUT_LINE" ]]; then
    echo "FAIL: both 'buildah push' and 'kubectl rollout' must be present"
    exit 1
fi
if [[ "$PUSH_LINE" -gt "$ROLLOUT_LINE" ]]; then
    echo "FAIL: buildah push (line $PUSH_LINE) must precede kubectl rollout (line $ROLLOUT_LINE)"
    exit 1
fi

# Stage 3: correct namespace
if ! grep -q "\-n doable" "$OUTPUT"; then
    echo "FAIL: kubectl rollout must use namespace '-n doable'"
    exit 1
fi

# workstation-api commands must NOT appear
if grep -q "just release" "$OUTPUT"; then
    echo "FAIL: 'just release' is for workstation-api only, not doable"
    exit 1
fi

# Stage 4: verification step present
if ! grep -qiE "curl|verify|stage 4" "$OUTPUT"; then
    echo "FAIL: Stage 4 verification step required"
    exit 1
fi

echo "PASS"
exit 0
```

**Step 3: Write workstation-api instruction.md**

```markdown
# Deploy the workstation-api Service

You are working in the ~/workspace ICM workspace. CLAUDE.md has been read and you have been routed to workflows/deploy-service/CONTEXT.md (contents provided as your system context).

## Task

Deploy the workstation-api Rust service. The source is at `~/workstation-api`. The Kubernetes namespace is `workstations`.

Produce a deployment plan at `/tmp/eval-output/plan.md` that covers all required stages with the exact commands for each stage and a verification step per stage.
```

**Step 4: Write workstation-api test.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/plan.md"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: plan.md not found at $OUTPUT"
    exit 1
fi

# just release must be present
if ! grep -q "just release" "$OUTPUT"; then
    echo "FAIL: workstation-api must use 'just release' for build+push"
    exit 1
fi

# buildah push must NOT appear after just release (just release handles push internally)
RELEASE_LINE=$(grep -n "just release" "$OUTPUT" | head -1 | cut -d: -f1)
PUSH_LINES=$(grep -n "buildah push" "$OUTPUT" | wc -l)

if [[ "$PUSH_LINES" -gt 0 ]]; then
    FIRST_PUSH=$(grep -n "buildah push" "$OUTPUT" | head -1 | cut -d: -f1)
    if [[ "$FIRST_PUSH" -gt "$RELEASE_LINE" ]]; then
        echo "FAIL: buildah push must NOT appear after 'just release' (line $RELEASE_LINE) — just release handles push internally"
        exit 1
    fi
fi

# Must proceed to verification (kubectl or curl)
if ! grep -qiE "kubectl rollout|curl.*healthz|stage 4|verify" "$OUTPUT"; then
    echo "FAIL: must proceed to verification after just release"
    exit 1
fi

# Correct namespace
if grep -qi "\-n doable" "$OUTPUT"; then
    echo "FAIL: workstation-api uses namespace 'workstations', not 'doable'"
    exit 1
fi

# Health endpoint
if ! grep -q "healthz" "$OUTPUT"; then
    echo "FAIL: Stage 4 must verify workstation-api via /healthz endpoint"
    exit 1
fi

# npm run build must NOT appear (that's the doable build step)
if grep -q "npm run build" "$OUTPUT"; then
    echo "FAIL: 'npm run build' is for doable only — workstation-api uses 'just release'"
    exit 1
fi

echo "PASS"
exit 0
```

**Step 5: Make test scripts executable**

```bash
chmod +x ~/claude-code-skills/evals/workspace/deploy-service/task-doable/test.sh
chmod +x ~/claude-code-skills/evals/workspace/deploy-service/task-workstation-api/test.sh
```

**Step 6: Commit**

```bash
cd ~/claude-code-skills
git add evals/workspace/deploy-service/
git commit -m "feat: add deploy-service eval tasks for doable and workstation-api paths"
```

---

### Task 14: Create the runner/workspace Python sub-package

**Files:**
- Create: `~/claude-code-skills/evals/runner/workspace/__init__.py`
- Create: `~/claude-code-skills/evals/runner/workspace/dataset.py`
- Create: `~/claude-code-skills/evals/runner/workspace/task.py`
- Create: `~/claude-code-skills/evals/runner/workspace/run.py`

**Step 1: Create __init__.py**

```python
# runner/workspace — workspace eval runner
```

**Step 2: Create dataset.py**

```python
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from pydantic_evals import Case, Dataset
from pydantic_evals.evaluators import Evaluator

from runner.solving.evaluators import BashGrader, StructuredRubricJudge

EVALS_ROOT: Path = Path(__file__).parent.parent.parent
WORKSPACE_ROOT: Path = EVALS_ROOT.parent.parent / "workspace"

WORKSPACE_WORKFLOWS: list[str] = [
    "deploy-service",
    "provision-vm",
    "release-nixos",
]

OUTPUT_FILENAMES: dict[tuple[str, str], str] = {
    ("deploy-service", "task-doable"): "plan.md",
    ("deploy-service", "task-workstation-api"): "plan.md",
    ("provision-vm", "task-with-goal"): "plan.md",
    ("provision-vm", "task-without-goal"): "plan.md",
    ("release-nixos", "task-local"): "plan.md",
}


@dataclass
class WorkspaceInput:
    instruction: str
    workflow: str
    task_id: str
    output_filename: str


@dataclass
class WorkspaceOutput:
    content: str
    stdout: str
    stderr: str
    timed_out: bool
    tmpdir: str
    returncode: int


@dataclass
class WorkspaceMetadata:
    test_script: Path
    quality_rubric: str | None


def build_workspace_dataset(
    workflow_filter: str | None = None,
    task_filter: str | None = None,
    with_quality: bool = False,
) -> Dataset[WorkspaceInput, WorkspaceOutput, WorkspaceMetadata]:
    cases: list[Case] = []

    workflows_dir = EVALS_ROOT / "workspace"
    workflows = WORKSPACE_WORKFLOWS if not workflow_filter else [workflow_filter]

    for workflow in workflows:
        tasks_dir = workflows_dir / workflow
        if not tasks_dir.exists():
            continue

        for task_path in sorted(tasks_dir.iterdir()):
            if not task_path.is_dir():
                continue

            task_id = task_path.name
            if task_filter and task_id != task_filter:
                continue

            instruction_path = task_path / "instruction.md"
            test_script_path = task_path / "test.sh"

            if not instruction_path.exists() or not test_script_path.exists():
                continue

            instruction = instruction_path.read_text()
            output_filename = OUTPUT_FILENAMES.get((workflow, task_id), "plan.md")

            quality_rubric: str | None = None
            quality_path = task_path / "quality.md"
            if with_quality and quality_path.exists():
                quality_rubric = quality_path.read_text()

            evaluators: list[Evaluator] = [BashGrader()]
            if with_quality and quality_rubric:
                evaluators.append(StructuredRubricJudge())

            cases.append(
                Case(
                    name=f"{workflow}::{task_id}",
                    inputs=WorkspaceInput(
                        instruction=instruction,
                        workflow=workflow,
                        task_id=task_id,
                        output_filename=output_filename,
                    ),
                    metadata=WorkspaceMetadata(
                        test_script=test_script_path,
                        quality_rubric=quality_rubric,
                    ),
                    evaluators=evaluators,
                )
            )

    return Dataset(name="workspace", cases=cases)
```

**Step 3: Create task.py**

```python
from __future__ import annotations

import tempfile
from pathlib import Path

from pydantic_ai import Agent

from runner.workspace.dataset import EVALS_ROOT, WORKSPACE_ROOT, WorkspaceInput, WorkspaceOutput

WORKSPACE_MODEL: str = "anthropic:claude-haiku-4-5-20251001"


def _load_workflow_context(workflow: str) -> str:
    context_path = WORKSPACE_ROOT / workflow / "CONTEXT.md"
    if not context_path.exists():
        raise FileNotFoundError(f"CONTEXT.md not found for workflow: {workflow}")
    return context_path.read_text()


async def run_workspace(inputs: WorkspaceInput, model: str = WORKSPACE_MODEL) -> WorkspaceOutput:
    """Run the workspace workflow eval.

    Injects the workflow CONTEXT.md as the system prompt with a preamble
    that simulates the agent having already navigated from CLAUDE.md.
    """
    context_body = _load_workflow_context(inputs.workflow)

    system_prompt = (
        f"You have read ~/workspace/CLAUDE.md and have been routed to "
        f"workflows/{inputs.workflow}/CONTEXT.md. "
        f"The following is that file's contents.\n\n"
        f"{context_body}\n\n"
        f"Execute the workflow stage contracts for the task described by the user. "
        f"Produce your deployment plan at /tmp/eval-output/{inputs.output_filename} "
        f"with labeled ## Stage N sections. Each stage section must include "
        f"the exact commands to run and the verification step."
    )

    tmpdir = tempfile.mkdtemp(prefix=f"eval-workspace-{inputs.workflow}-{inputs.task_id}-")
    output_path = Path(tmpdir) / inputs.output_filename

    agent = Agent(model, instructions=system_prompt, output_type=str)
    result = await agent.run(inputs.instruction)
    content = result.output if isinstance(result.output, str) else str(result.output)

    output_path.write_text(content)

    return WorkspaceOutput(
        content=content,
        stdout="",
        stderr="",
        timed_out=False,
        tmpdir=tmpdir,
        returncode=0,
    )
```

**Step 4: Create run.py**

```python
from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

from runner.workspace.dataset import build_workspace_dataset
from runner.workspace.task import WORKSPACE_MODEL, run_workspace

RESULTS_DIR: Path = Path(__file__).parent.parent.parent / "results"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run workspace workflow evals")
    parser.add_argument("--workflow", help="Filter to a specific workflow")
    parser.add_argument("--task", help="Filter to a specific task")
    parser.add_argument("--with-quality", action="store_true", help="Include rubric judge")
    parser.add_argument("--no-save", action="store_true", help="Skip saving results JSON")
    parser.add_argument("--no-cleanup", action="store_true", help="Keep tmpdir artifacts")
    args = parser.parse_args()

    dataset = build_workspace_dataset(
        workflow_filter=args.workflow,
        task_filter=args.task,
        with_quality=args.with_quality,
    )

    report = dataset.evaluate_sync(run_workspace)
    report.print(include_input=True, include_output=True)

    if not args.no_save:
        RESULTS_DIR.mkdir(exist_ok=True)
        timestamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
        results_file = RESULTS_DIR / f"workspace-{timestamp}.json"
        results_file.write_text(json.dumps(report.model_dump(), indent=2, default=str))
        print(f"\nResults saved to {results_file}")


if __name__ == "__main__":
    main()
```

**Step 5: Verify imports resolve**

```bash
cd ~/claude-code-skills/evals
uv run python -c "from runner.workspace.dataset import build_workspace_dataset; print('OK')"
```

Expected: `OK`

**Step 6: Run the eval (dry run with available tasks)**

```bash
cd ~/claude-code-skills/evals
uv run python -m runner.workspace --workflow deploy-service
```

Expected: eval runs both deploy-service tasks, prints PASS/FAIL per case.

**Step 7: Commit**

```bash
cd ~/claude-code-skills
git add evals/runner/workspace/
git commit -m "feat: add runner/workspace Python eval sub-package for ICM workflow evals"
```

---

## WORKSTREAM 5 — Push Everything

### Task 15: Push all repos

**Step 1: Push claude-code-skills**

```bash
cd ~/claude-code-skills
git log --oneline -8
git push origin main
```

Expected: all commits pushed (hooks, evals, check-goals update).

**Step 2: Push nixos-config**

```bash
cd ~/nixos-config
git log --oneline -3
git push origin homelab
```

Expected: mcp.nix hook wiring pushed.

**Step 3: Push workstation-api**

```bash
cd ~/workstation-api
git log --oneline -3
git push origin main
```

Expected: CLAUDE.md update pushed.

**Step 4: Confirm workspace already pushed (done in Workstream 1)**

```bash
cd ~/workspace
git log --oneline -5
```

Expected: 4 fix commits visible, already on remote.

---

## Notes for the implementer

- **Workstream order matters for Workstream 2**: check-goals.sh (Task 9) must be committed before mcp.nix wiring (Task 10). The hook needs to exist before it is referenced in Nix.
- **Workstreams 1 and 3 are independent**: workspace fixes and workstation-api CLAUDE.md can be done in parallel if desired.
- **Workstream 4 (evals) depends on Workstream 1**: the eval tasks reference deploy-service/CONTEXT.md content — run fixes first so the eval content matches the corrected workflow file.
- **validate-rust.sh on VMs**: `cargo check` is safe on VMs (no musl flag required, unlike `cargo build`). No VM exclusion needed.
- **extract-instincts.sh requires `claude` in PATH**: the hook calls `claude -p`. On the physical host this is available via NixOS. Confirm with `which claude`.
- **`~/.claude/skills/learned/` auto-discovery**: Claude Code loads skills from `~/.claude/skills/` and subdirectories. Learned skills will be picked up automatically on next session start without any additional configuration.
