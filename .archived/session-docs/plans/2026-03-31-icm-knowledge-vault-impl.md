# ICM Knowledge Vault — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `~/workspace` and `~/knowledge-vault` into a single ICM-native knowledge vault, add two-stage Haiku retrieval hook, and wire session recording and per-project ADR/RFC tracking.

**Architecture:** Unified `~/workspace` repo serves as both ICM routing layer and Obsidian knowledge vault. INDEX.md files (2-5 lines) are the activation signal Haiku reads in Stage 1; CONTEXT.md files are the payload loaded when a room is activated. A new `retrieve-context.sh` hook fires on `UserPromptSubmit`, runs two Haiku calls, and prints a summary + file pointers — never full content. A persist hook writes AI session records at Stop.

**Tech Stack:** bash, claude-haiku-4-5-20251001 (via `claude -p`), jq, git, NixOS Home Manager (hook wiring via `mcp.nix`)

**Repos touched:**
- `~/workspace` — unified vault (structure changes, new files)
- `~/claude-code-skills` — new hook + skill update (push triggers flake update)
- `~/nixos-config` — wire new hook in `mcp.nix`, rebuild

---

## Task 1: Add INDEX.md to all existing workspace rooms

INDEX.md is the ICM activation signal. Haiku reads it to decide if a room is relevant. 2-5 lines only.

**Files:**
- Create: `~/workspace/homelab/INDEX.md`
- Create: `~/workspace/dev/INDEX.md`
- Create: `~/workspace/workflows/INDEX.md`
- Create: `~/workspace/content/INDEX.md`
- Create: `~/workspace/local/INDEX.md`

**Step 1: Create homelab INDEX.md**

```bash
cat > ~/workspace/homelab/INDEX.md << 'EOF'
Load this room if: NixOS configuration, k3s cluster, Flux GitOps, SOPS/age secrets, KubeVirt VMs, Harbor registry, homelab infrastructure, host management, cluster bootstrapping.
Skip if: pure application code, personal scripts, writing, or research notes.
Key files: CONTEXT.md, cluster-overview.md, hosts/, runbooks/, decisions/
EOF
```

**Step 2: Create dev INDEX.md**

```bash
cat > ~/workspace/dev/INDEX.md << 'EOF'
Load this room if: doable SvelteKit UI, workstation-api Rust service, application development, frontend, backend, database schema, container builds, service deployment.
Skip if: homelab infrastructure, personal scripts, or writing.
Key files: CONTEXT.md, doable/INDEX.md, workstation-api/INDEX.md
EOF
```

**Step 3: Create workflows INDEX.md**

```bash
cat > ~/workspace/workflows/INDEX.md << 'EOF'
Load this room if: deploying a service, provisioning a claude-worker VM, releasing a NixOS config change, multi-step pipeline, build-push-apply cycle.
Skip if: exploratory work, writing, or infrastructure-only changes not needing a pipeline.
Key files: CONTEXT.md, deploy-service/CONTEXT.md, provision-vm/CONTEXT.md, release-nixos/CONTEXT.md
EOF
```

**Step 4: Create content INDEX.md**

```bash
cat > ~/workspace/content/INDEX.md << 'EOF'
Load this room if: research notes, writing drafts, learning summaries, blog posts, documentation writing — no code changes involved.
Skip if: any coding, infrastructure, or deployment work.
Key files: CONTEXT.md, notes/
EOF
```

**Step 5: Create local INDEX.md**

```bash
cat > ~/workspace/local/INDEX.md << 'EOF'
Load this room if: personal shell scripts, local automation, one-off tools, machine-local configuration not tracked in nixos-config.
Skip if: anything that should be deployed to the cluster or committed to a project repo.
Key files: CONTEXT.md
EOF
```

**Step 6: Commit**

```bash
cd ~/workspace
git add homelab/INDEX.md dev/INDEX.md workflows/INDEX.md content/INDEX.md local/INDEX.md
git commit -m "feat: add INDEX.md activation signals to all rooms"
```

---

## Task 2: Add project-level INDEX.md and decisions/ structure inside dev/

Projects inside `dev/` get their own INDEX.md (finer-grained activation) and a `decisions/` folder for ADRs and RFCs.

**Files:**
- Create: `~/workspace/dev/doable/INDEX.md`
- Create: `~/workspace/dev/doable/decisions/.gitkeep`
- Create: `~/workspace/dev/workstation-api/INDEX.md`
- Create: `~/workspace/dev/workstation-api/decisions/.gitkeep`

**Step 1: Create doable project structure**

```bash
mkdir -p ~/workspace/dev/doable/decisions

cat > ~/workspace/dev/doable/INDEX.md << 'EOF'
Load this room if: specifically working on the doable UI (SvelteKit 2, Svelte 5 runes, Tailwind v4, PostgreSQL), doable.sammasak.dev, frontend components, live preview proxy.
Key files: CONTEXT.md (if present), architecture.md (if present), decisions/
EOF
```

**Step 2: Create workstation-api project structure**

```bash
mkdir -p ~/workspace/dev/workstation-api/decisions

cat > ~/workspace/dev/workstation-api/INDEX.md << 'EOF'
Load this room if: specifically working on workstation-api (Rust, Axum, PostgreSQL), workspace CRD controller, KubeVirt VM orchestration API, Rust Axum routes.
Key files: CONTEXT.md (if present), architecture.md (if present), decisions/
EOF
```

**Step 3: Commit**

```bash
cd ~/workspace
git add dev/
git commit -m "feat: add project-level INDEX.md and decisions/ for doable and workstation-api"
```

---

## Task 3: Add claude-code-skills room to workspace

The skills repo needs its own ICM room so Claude can retrieve context about hooks, agents, and skills when working on them.

**Files:**
- Create: `~/workspace/claude-code-skills/INDEX.md`
- Create: `~/workspace/claude-code-skills/CONTEXT.md`
- Create: `~/workspace/claude-code-skills/decisions/.gitkeep`

**Step 1: Create the room**

```bash
mkdir -p ~/workspace/claude-code-skills/decisions

cat > ~/workspace/claude-code-skills/INDEX.md << 'EOF'
Load this room if: working on Claude skills, hooks, agents, ICM methodology, knowledge vault design, claude-worker architecture, hook wiring, skill authoring, extract-instincts, retrieve-context.
Key files: CONTEXT.md, architecture.md (if present), decisions/
EOF

cat > ~/workspace/claude-code-skills/CONTEXT.md << 'EOF'
# Claude Code Skills

The skills repo lives at ~/claude-code-skills. It contains:
- skills/<name>/SKILL.md — injectable skill definitions
- hooks/<name>.sh — lifecycle hook scripts
- agents/<name>.md — sub-agent definitions
- docs/plans/ — design and implementation docs
- evals/ — skill evaluation harness

## Key conventions
Skills are delivered via NixOS Home Manager (skills.nix symlinks them to ~/.claude/skills/).
Hooks are wired in nixos-config/modules/programs/cli/claude-code/mcp.nix.
After adding a new hook: push to claude-code-skills → nix flake update in nixos-config → rebuild.

## Working on hooks
- Hook scripts live in ~/claude-code-skills/hooks/
- Test locally by running the script directly with sample stdin JSON
- Wire in mcp.nix using the skillsSrc variable (Nix store path to the hooks/ dir)

## Working on skills
- Each skill is a directory: skills/<name>/SKILL.md
- The SKILL.md is the full skill content (no other files needed)
- skills.nix auto-discovers and symlinks all skills/ subdirectories

## Workflow to deploy changes
```bash
cd ~/claude-code-skills && git push
cd ~/nixos-config && nix flake update claude-code-skills
sudo nixos-rebuild switch --flake .#acer-swift
```
EOF
```

**Step 2: Commit**

```bash
cd ~/workspace
git add claude-code-skills/
git commit -m "feat: add claude-code-skills room with INDEX.md and CONTEXT.md"
```

---

## Task 4: Create sessions/ room

All recorded work lives here — meetings, work sessions, hackathons, AI sessions.

**Files:**
- Create: `~/workspace/sessions/INDEX.md`
- Create: `~/workspace/sessions/CONTEXT.md`
- Create: `~/workspace/sessions/meetings/.gitkeep`
- Create: `~/workspace/sessions/work-sessions/.gitkeep`
- Create: `~/workspace/sessions/ai-sessions/.gitkeep`

**Step 1: Create the sessions room**

```bash
mkdir -p ~/workspace/sessions/meetings
mkdir -p ~/workspace/sessions/work-sessions
mkdir -p ~/workspace/sessions/ai-sessions

cat > ~/workspace/sessions/INDEX.md << 'EOF'
Load this room if: looking for prior decisions, session history, what was built before, past meetings, previous debugging sessions, historical context about any project or decision.
Key files: meetings/, work-sessions/, ai-sessions/
EOF

cat > ~/workspace/sessions/CONTEXT.md << 'EOF'
# Sessions

All recorded work lives here. Three types:

## meetings/
Human or human+Claude sync meetings, planning sessions, reviews.
Filename: YYYY-MM-DD-topic.md
Frontmatter: date, type: meeting, attendees, projects, decisions_made

## work-sessions/
Focused work: spikes, hackathons, implementation sessions, debugging.
Filename: YYYY-MM-DD-topic.md
Frontmatter: date, type: work-session, session_type, project, goal, outcome

## ai-sessions/
Claude's own record of what it did. Written by the persist hook at session end.
Filename: YYYY-MM-DD-topic.md
Frontmatter: date, type: ai-session, project, goal, outcome, files_modified, decisions_made

## Creating a session record
- Always use date-prefixed filenames
- Link decisions to ADRs: see [[dev/doable/decisions/ADR-001-foo]]
- Link to prior sessions when continuing work
EOF

touch ~/workspace/sessions/meetings/.gitkeep
touch ~/workspace/sessions/work-sessions/.gitkeep
touch ~/workspace/sessions/ai-sessions/.gitkeep
```

**Step 2: Commit**

```bash
cd ~/workspace
git add sessions/
git commit -m "feat: add sessions room for meetings, work-sessions, and ai-sessions"
```

---

## Task 5: Add homelab decisions/ folder and knowledge/ room

Homelab gets a decisions/ folder for infrastructure ADRs. A new knowledge/ room holds cross-cutting reference material.

**Files:**
- Create: `~/workspace/homelab/decisions/.gitkeep`
- Create: `~/workspace/knowledge/INDEX.md`
- Create: `~/workspace/knowledge/kubernetes/.gitkeep`
- Create: `~/workspace/knowledge/nix/.gitkeep`
- Create: `~/workspace/knowledge/ai-agents/.gitkeep`

**Step 1: Add homelab decisions/**

```bash
mkdir -p ~/workspace/homelab/decisions
touch ~/workspace/homelab/decisions/.gitkeep
```

**Step 2: Create knowledge room**

```bash
mkdir -p ~/workspace/knowledge/kubernetes
mkdir -p ~/workspace/knowledge/nix
mkdir -p ~/workspace/knowledge/ai-agents

cat > ~/workspace/knowledge/INDEX.md << 'EOF'
Load this room if: looking for reusable patterns, cross-project techniques, Kubernetes patterns, NixOS patterns, Rust patterns, AI agent patterns, general reference material not specific to one project.
Key files: kubernetes/, nix/, ai-agents/
EOF
```

**Step 3: Commit**

```bash
cd ~/workspace
git add homelab/decisions/ knowledge/
git commit -m "feat: add homelab/decisions and knowledge/ cross-cutting room"
```

---

## Task 6: Update CLAUDE.md routing table

The master routing table needs to reference all new rooms and the updated mental model.

**Files:**
- Modify: `~/workspace/CLAUDE.md`

**Step 1: Read current CLAUDE.md**

```bash
cat ~/workspace/CLAUDE.md
```

**Step 2: Rewrite CLAUDE.md**

Replace the full content with:

```markdown
# Workspace

This is an ICM (Interpreted Context Methodology) workspace and knowledge vault.
Each folder is a room. Read INDEX.md to decide if a room is relevant.
Read CONTEXT.md for full operational instructions once a room is activated.

## Routing Table

| Task | Room | Read first |
|------|------|------------|
| NixOS, k3s, Flux, SOPS, KubeVirt, VMs, Harbor | homelab/ | homelab/INDEX.md |
| doable UI (SvelteKit), app development | dev/ | dev/INDEX.md → dev/doable/INDEX.md |
| workstation-api (Rust Axum) | dev/ | dev/INDEX.md → dev/workstation-api/INDEX.md |
| Deploy service, provision VM, release NixOS | workflows/ | workflows/INDEX.md |
| Skills, hooks, agents, ICM, claude-worker | claude-code-skills/ | claude-code-skills/INDEX.md |
| Prior decisions, session history, what was built | sessions/ | sessions/INDEX.md |
| Cross-cutting patterns, Kubernetes/Nix/AI guides | knowledge/ | knowledge/INDEX.md |
| Research, writing, notes (no code) | content/ | content/INDEX.md |
| Personal scripts, local tools | local/ | local/INDEX.md |

## Architecture Decisions and RFCs

ADRs live inside their project room under decisions/:
- homelab/decisions/ADR-NNN-slug.md
- dev/doable/decisions/ADR-NNN-slug.md
- dev/workstation-api/decisions/ADR-NNN-slug.md
- claude-code-skills/decisions/ADR-NNN-slug.md

RFCs (pre-decision proposals): RFC-YYYY-MM-slug.md in same decisions/ folder.

## Session Records

All work is recorded in sessions/:
- sessions/meetings/ — human or human+Claude meetings
- sessions/work-sessions/ — spikes, hackathons, implementation sessions
- sessions/ai-sessions/ — Claude's own session records (written by persist hook)

## ICM Principles

1. Read INDEX.md before deciding if a room applies
2. Read CONTEXT.md for full instructions once activated
3. All other files are named after their subject (not AI files)
4. Link between rooms using relative paths
5. Every significant decision gets an ADR in the relevant room
```

**Step 3: Verify and commit**

```bash
cd ~/workspace
git add CLAUDE.md
git commit -m "feat: update CLAUDE.md routing table with all new rooms and conventions"
```

---

## Task 7: Write retrieve-context.sh hook

Two-stage Haiku workflow. Fires on `UserPromptSubmit`. Reads INDEX.md files to find relevant rooms, then reads CONTEXT.md files and summarizes. Prints a signpost (summary + file pointers), never full content. Silent if nothing is relevant.

**Files:**
- Create: `~/claude-code-skills/hooks/retrieve-context.sh`

**Step 1: Write the hook**

```bash
cat > ~/claude-code-skills/hooks/retrieve-context.sh << 'HOOKEOF'
#!/usr/bin/env bash
# UserPromptSubmit hook — two-stage Haiku context retrieval from ICM workspace.
#
# Stage 1: tree + INDEX.md scan → which rooms are relevant?
# Stage 2: read CONTEXT.md for relevant rooms → summarize + list specific files.
# Output: summary paragraph + file pointers. Silent if nothing relevant.
#
# Physical host ONLY (VM agents have their own CONTEXT via goal/CLAUDE.md).
# Must complete in <5s total.

set -euo pipefail

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

STAGE1=$(echo "$STAGE1" | tr -d '\n' | xargs)
[ -z "$STAGE1" ] || [ "$STAGE1" = "NONE" ] && exit 0

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
HOOKEOF

chmod +x ~/claude-code-skills/hooks/retrieve-context.sh
```

**Step 2: Test the hook manually**

```bash
echo '{"prompt": "I need to debug the SOPS decryption failure on the cluster"}' \
  | ~/claude-code-skills/hooks/retrieve-context.sh
```

Expected output: a summary mentioning homelab and SOPS, with file pointers to homelab CONTEXT.md or runbooks.

```bash
echo '{"prompt": "ok"}' \
  | ~/claude-code-skills/hooks/retrieve-context.sh
```

Expected: no output (short prompt guard triggers).

**Step 3: Commit to claude-code-skills**

```bash
cd ~/claude-code-skills
git add hooks/retrieve-context.sh
git commit -m "feat: add retrieve-context.sh — two-stage Haiku ICM retrieval hook"
git push
```

---

## Task 8: Write persist-session.sh hook

At session end (Stop hook), Haiku writes an AI session record to `sessions/ai-sessions/`. Only fires on physical host when meaningful work occurred.

**Files:**
- Create: `~/claude-code-skills/hooks/persist-session.sh`

**Step 1: Write the hook**

```bash
cat > ~/claude-code-skills/hooks/persist-session.sh << 'HOOKEOF'
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

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Guard: minimum 8 user messages (meaningful session)
MSG_COUNT=$(grep -c '"type":"user"' "$TRANSCRIPT" 2>/dev/null || echo "0")
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
HOOKEOF

chmod +x ~/claude-code-skills/hooks/persist-session.sh
```

**Step 2: Test manually**

```bash
# Simulate a Stop hook call (needs a real transcript path to work fully)
echo '{"transcript_path": "", "session_id": "test-123"}' \
  | ~/claude-code-skills/hooks/persist-session.sh
```

Expected: exits silently (empty transcript path guard).

**Step 3: Commit**

```bash
cd ~/claude-code-skills
git add hooks/persist-session.sh
git commit -m "feat: add persist-session.sh — AI session record writer"
git push
```

---

## Task 9: Wire new hooks in nixos-config mcp.nix

Add `retrieve-context.sh` as a `UserPromptSubmit` hook and `persist-session.sh` to the Stop chain (after `check-goals.sh`, before `extract-instincts.sh`).

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`

**Step 1: Read current mcp.nix hooks section**

```bash
grep -n "hooks\|Stop\|UserPrompt\|retrieve\|persist" \
  ~/nixos-config/modules/programs/cli/claude-code/mcp.nix
```

**Step 2: Update flake input**

```bash
cd ~/nixos-config
nix flake update claude-code-skills
```

Expected: `• Updated input 'claude-code-skills': ...`

**Step 3: Add UserPromptSubmit hook and persist-session to Stop chain**

In `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`, find the `hooks = {` block and add:

```nix
# Add inside hooks = { ... }:
UserPromptSubmit = [{
  hooks = [{
    type = "command";
    command = "${skillsSrc}/hooks/retrieve-context.sh";
    timeout = 8;
  }];
}];
```

And in the Stop hooks list, add `persist-session.sh` after `check-goals.sh`:

```nix
Stop = [{
  hooks = [
    {
      type = "command";
      command = "${skillsSrc}/hooks/check-goals.sh";
    }
    {
      type = "command";                                    # ADD THIS
      command = "${skillsSrc}/hooks/persist-session.sh";  # ADD THIS
    }                                                      # ADD THIS
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

**Step 4: Verify NixOS build**

```bash
cd ~/nixos-config
nix build .#nixosConfigurations.acer-swift.config.system.build.toplevel --no-link
```

Expected: build completes without errors.

**Step 5: Apply**

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#acer-swift
```

**Step 6: Verify hook is wired**

```bash
cat ~/.claude/settings.json | jq '.hooks.UserPromptSubmit'
```

Expected: array containing the retrieve-context.sh path.

**Step 7: Commit nixos-config**

```bash
cd ~/nixos-config
git add flake.lock modules/programs/cli/claude-code/mcp.nix
git commit -m "feat: wire retrieve-context and persist-session hooks"
git push
```

---

## Task 10: Update knowledge-vault SKILL.md

The skill needs to reflect the merged structure: workspace IS the vault, sessions are recorded automatically, ADRs go in project decisions/ folders.

**Files:**
- Modify: `~/claude-code-skills/skills/knowledge-vault/SKILL.md`

**Step 1: Read current skill**

```bash
cat ~/claude-code-skills/skills/knowledge-vault/SKILL.md
```

**Step 2: Rewrite the skill**

Replace the full content of `SKILL.md` with:

````markdown
---
name: knowledge-vault
description: Manage documentation in ~/workspace knowledge vault — create session records, ADRs, RFCs, and knowledge notes. Use when asked to document work, record decisions, or update vault content.
---

# Knowledge Vault

`~/workspace` is a unified ICM workspace and Obsidian knowledge vault.
All documentation, decisions, and session records live here alongside the routing layer.

## Vault Structure

```
~/workspace/
├── CLAUDE.md              ← routing table
├── homelab/               ← infrastructure docs
│   ├── INDEX.md           ← activation signal
│   ├── CONTEXT.md         ← operational context
│   ├── runbooks/          ← operational runbooks
│   └── decisions/         ← homelab ADRs and RFCs
├── dev/
│   ├── doable/decisions/  ← doable ADRs and RFCs
│   └── workstation-api/decisions/
├── claude-code-skills/decisions/
├── sessions/
│   ├── meetings/          ← meeting notes
│   ├── work-sessions/     ← spikes, hackathons, implementations
│   └── ai-sessions/       ← Claude session records (auto-written by hook)
└── knowledge/             ← cross-cutting reference
```

## File Naming Conventions

- Session files: `YYYY-MM-DD-topic.md` (date-prefixed)
- ADRs: `ADR-NNN-slug.md` (sequential per project)
- RFCs: `RFC-YYYY-MM-slug.md` (date-prefixed, pre-decision proposals)
- All other files: named after their subject (e.g. `cluster-overview.md`, `sops-integration.md`)

## Creating a Session Record

For meetings and work sessions, create the file manually:

```bash
VAULT=~/workspace
DATE=$(date +%Y-%m-%d)
TYPE=meetings  # or work-sessions
TOPIC="homelab-planning-sync"
FILE="$VAULT/sessions/$TYPE/$DATE-$TOPIC.md"
```

Frontmatter:
```yaml
---
date: 2026-03-31
type: meeting          # or work-session, ai-session
attendees: [lukas]     # for meetings
project: homelab       # primary project
goal: "one sentence"   # for work-sessions
outcome: "result"      # fill in at end
---
```

Commit after writing:
```bash
cd ~/workspace && git add sessions/ && git commit -m "session: $DATE $TOPIC" && git push
```

## Creating an ADR

ADRs live inside their project room under decisions/:

```bash
VAULT=~/workspace
PROJECT=homelab   # or dev/doable, dev/workstation-api, claude-code-skills
NUM=001
SLUG="use-flux-for-gitops"
FILE="$VAULT/$PROJECT/decisions/ADR-$NUM-$SLUG.md"
```

ADR frontmatter:
```yaml
---
status: accepted
date: 2026-03-31
supersedes: null
related: []
---
```

Required sections: Context, Decision (one sentence), Options Considered (table), Consequences, Links.

## Creating an RFC

RFC = pre-decision proposal. Name: `RFC-YYYY-MM-slug.md` in same decisions/ folder.
Once accepted, create the ADR and link from the RFC.

## Syncing Changes

Always commit and push after vault changes:
```bash
cd ~/workspace
git add .
git commit -m "docs: <describe change>"
git push
```

## INDEX.md and CONTEXT.md

These are the only AI-facing files. Do not rename them:
- `INDEX.md` — 2-5 lines, activation signal for Haiku retrieval
- `CONTEXT.md` — full operational instructions for Claude

All other files are named after their subject (human-readable, Obsidian-native).
````

**Step 3: Commit**

```bash
cd ~/claude-code-skills
git add skills/knowledge-vault/SKILL.md
git commit -m "docs: update knowledge-vault skill to reflect unified workspace vault"
git push
```

---

## Task 11: Migrate knowledge-vault content into workspace

Move content from `~/knowledge-vault` into the appropriate rooms in `~/workspace`. This is a read-and-copy operation — the knowledge-vault repo is not deleted, just archived.

**Step 1: Map content to destination rooms**

| Source | Destination |
|--------|------------|
| `~/knowledge-vault/Infrastructure/Runbooks/` | `~/workspace/homelab/runbooks/` |
| `~/knowledge-vault/Infrastructure/Concepts/` | `~/workspace/knowledge/nix/` |
| `~/knowledge-vault/Homelab/Architecture/` | `~/workspace/homelab/` |
| `~/knowledge-vault/Homelab/Runbooks/` | `~/workspace/homelab/runbooks/` |
| `~/knowledge-vault/Homelab/Concepts/` | `~/workspace/knowledge/kubernetes/` |
| `~/knowledge-vault/Homelab/Projects/` | relevant project rooms or homelab/ |
| `~/knowledge-vault/Development/Concepts/` | `~/workspace/knowledge/ai-agents/` |
| `~/knowledge-vault/Development/Projects/` | `~/workspace/dev/` or `~/workspace/claude-code-skills/` |

**Step 2: Copy files**

```bash
# Runbooks
cp ~/knowledge-vault/Infrastructure/Runbooks/*.md ~/workspace/homelab/runbooks/ 2>/dev/null || true
cp ~/knowledge-vault/Homelab/Runbooks/*.md ~/workspace/homelab/runbooks/ 2>/dev/null || true

# Architecture docs → homelab
cp ~/knowledge-vault/Homelab/Architecture/*.md ~/workspace/homelab/ 2>/dev/null || true

# Infrastructure concepts → knowledge/nix
cp ~/knowledge-vault/Infrastructure/Concepts/*.md ~/workspace/knowledge/nix/ 2>/dev/null || true

# Homelab concepts → knowledge/kubernetes
cp ~/knowledge-vault/Homelab/Concepts/*.md ~/workspace/knowledge/kubernetes/ 2>/dev/null || true

# Development concepts → knowledge/ai-agents
cp ~/knowledge-vault/Development/Concepts/*.md ~/workspace/knowledge/ai-agents/ 2>/dev/null || true
```

**Step 3: Review and strip old-format frontmatter**

Skim copied files. The old vault uses `domain:` and `type:` frontmatter fields that can stay — they don't conflict with the new structure. Remove any `status: draft` if promoting to final.

```bash
ls ~/workspace/homelab/runbooks/
ls ~/workspace/knowledge/kubernetes/
ls ~/workspace/knowledge/nix/
```

**Step 4: Commit migrated content**

```bash
cd ~/workspace
git add homelab/ knowledge/
git commit -m "docs: migrate knowledge-vault content into unified workspace"
git push
```

**Step 5: Archive the old vault repo**

```bash
cd ~/knowledge-vault
git commit --allow-empty -m "archived: content migrated to ~/workspace — this repo is now read-only"
git push
```

Add a note to `~/knowledge-vault/README.md`:
> **Archived 2026-03-31.** Content has been migrated to `~/workspace`. This repo is retained for historical reference only.

---

## Task 12: Configure Obsidian to open ~/workspace as vault

**Step 1: Open Obsidian and switch vault**

In Obsidian: File → Open vault → Open folder as vault → select `~/workspace`

Or if Obsidian is not yet installed on this machine, copy `.obsidian/` config from `~/knowledge-vault`:

```bash
cp -r ~/knowledge-vault/.obsidian ~/workspace/.obsidian
```

**Step 2: Verify Obsidian opens correctly**

Open Obsidian with ~/workspace. Confirm:
- Left sidebar shows room folders (homelab, dev, sessions, etc.)
- Graph view shows links between notes
- Files are browsable

**Step 3: Add .obsidian to .gitignore if not already present**

```bash
cd ~/workspace
grep ".obsidian" .gitignore 2>/dev/null || echo ".obsidian" >> .gitignore
git add .gitignore
git commit -m "chore: gitignore .obsidian config"
git push
```

---

## Verification Checklist

After all tasks complete:

- [ ] `ls ~/workspace/` shows: CLAUDE.md, homelab/, dev/, claude-code-skills/, workflows/, sessions/, knowledge/, content/, local/
- [ ] Every folder has an INDEX.md
- [ ] `cat ~/.claude/settings.json | jq '.hooks.UserPromptSubmit'` returns the retrieve-context.sh entry
- [ ] Manual test: `echo '{"prompt": "debug the SOPS issue on cluster"}' | ~/claude-code-skills/hooks/retrieve-context.sh` returns a summary mentioning homelab
- [ ] Manual test: short prompt `echo '{"prompt": "ok"}' | ~/claude-code-skills/hooks/retrieve-context.sh` returns nothing
- [ ] Obsidian opens ~/workspace and all rooms are browsable
- [ ] `cd ~/workspace && git log --oneline -10` shows all task commits
