# Hook Architecture v2 — Design Document

**Date:** 2026-03-31
**Status:** Approved
**Repos:** `~/claude-code-skills`, `~/workspace`, `~/nixos-config`

## Problem

The v1 hook system (10 hooks across 4 Claude Code hook points) has structural issues:

1. **Retrieval has no memory** — `retrieve-context.sh` re-retrieves the same rooms every prompt, no session cache, no cross-session learning
2. **Stop chain ordering is wrong** — session records written before knowing if work succeeded; `check-goals.sh` can block subsequent hooks for 5 minutes
3. **Split-brain session recording** — `persist-session.sh` (physical) and `write-session-state.sh` (VM) do the same thing with different formats and destinations
4. **extract-instincts has no quality gate** — no dedup, no confidence scoring, no expiry; learned skills accumulate noise
5. **Validation hooks can't suggest fixes** — block/warn but offer no alternative
6. **No observability** — every hook silently succeeds or fails; no audit trail, no metrics
7. **check-loop.sh is weak** — exact-match only, can't detect semantic loops or failure-retry patterns
8. **report-activity.sh is VM-only** — physical host sessions have zero activity tracking
9. **Missing hook points** — no post-commit, no goal lifecycle, no context compaction re-injection
10. **No cross-session intelligence** — each session starts fresh; the vault grows but retrieval doesn't get smarter

## Solution: Hybrid Architecture (Approach C)

Three new layers added to the existing script-per-hook model:

### Layer 1: ICM Prompt Templates

Move all Haiku prompts from bash heredocs into editable markdown files in the workspace.

**Location:** `~/workspace/workflows/hooks/`

```
~/workspace/workflows/hooks/
├── INDEX.md
├── CONTEXT.md
├── retrieve-context/
│   ├── stage1-room-selection.md
│   └── stage2-summarize.md
├── persist-session/
│   └── extract-summary.md
├── extract-instincts/
│   └── extract-learnings.md
└── write-session-state/
    └── handoff-document.md
```

Each template uses `{{VARIABLE}}` placeholders interpolated by the hook script:

```markdown
<!-- stage1-room-selection.md -->
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
```

**Why:** Prompts are editable without touching code. Version-controlled. Visible in Obsidian. No NixOS rebuild to improve retrieval quality.

### Layer 2: Shared State

A session-scoped JSON file that hooks read and write, enabling memory within a session and coordination between hooks.

**Location:** `/tmp/claude-hook-state-${CLAUDE_SESSION_ID}.json`

**Schema:**

```json
{
  "session_id": "abc-123",
  "started_at": "2026-03-31T14:00:00Z",
  "prompt_count": 7,
  "retrieve": {
    "rooms_activated": ["homelab", "dev/doable"],
    "last_activated_at": "2026-03-31T14:02:30Z",
    "last_prompt_words": "debug k3s node failure",
    "context_injected": true
  },
  "repos_touched": ["homelab-gitops", "nixos-config"],
  "tools_used": {"Bash": 14, "Write": 3, "Edit": 8},
  "errors_seen": 2,
  "loop_count": 0,
  "topic": "homelab",
  "goal_status": null
}
```

**Hook usage matrix:**

| Hook | Reads | Writes |
|------|-------|--------|
| `retrieve-context.sh` | `rooms_activated`, `last_prompt_words` | `rooms_activated`, `last_prompt_words`, `prompt_count++` |
| `persist-session.sh` | `topic`, `repos_touched`, `tools_used`, `errors_seen` | — |
| `extract-instincts.sh` | `topic`, `errors_seen` | — |
| `check-goals.sh` | — | `goal_status` |
| `write-session-state.sh` | `goal_status`, `repos_touched`, `tools_used` | — |
| `check-loop.sh` | — | `loop_count`, `errors_seen++` |
| `validate-bash.sh` | — | `repos_touched` |
| `validate-rust.sh` | — | `errors_seen++` |

**Shared helpers** in `~/claude-code-skills/hooks/lib/state.sh`:

```bash
STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"

init_state() {
  [ -f "$STATE_FILE" ] && return
  cat > "$STATE_FILE" << EOF
{"session_id":"${CLAUDE_SESSION_ID:-$$}","started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","prompt_count":0,"retrieve":{},"repos_touched":[],"tools_used":{},"errors_seen":0,"loop_count":0,"goal_status":null}
EOF
}

read_state() { jq -r "$1" "$STATE_FILE" 2>/dev/null; }

update_state() {
  local tmp=$(mktemp)
  jq "$1" "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE"
}
```

**Lifecycle:** Created on first hook invocation. Dies with the session (`/tmp/`). Cross-session persistence is the hook log's job.

### Layer 3: Hook Log

An append-only JSONL file in the workspace for observability and cross-session intelligence.

**Location:** `~/workspace/.hook-log/YYYY-MM-DD.jsonl`

**Entry format:**

```json
{"ts":"2026-03-31T14:02:30Z","hook":"retrieve-context","session":"abc-123","duration_ms":3200,"rooms_activated":["homelab","dev/doable"],"result":"signpost","prompt_words":12}
{"ts":"2026-03-31T14:02:31Z","hook":"validate-bash","session":"abc-123","duration_ms":5,"command":"git push --force","result":"blocked"}
{"ts":"2026-03-31T15:30:00Z","hook":"persist-session","session":"abc-123","duration_ms":4100,"result":"wrote","file":"sessions/ai-sessions/2026-03-31-homelab-k3s-debug.md"}
```

**Shared helpers** in `~/claude-code-skills/hooks/lib/log.sh`:

```bash
LOG_DIR="${HOME}/workspace/.hook-log"

log_hook() {
  local hook="$1" result="$2" duration="$3"
  shift 3
  mkdir -p "$LOG_DIR"
  local extra=""
  [ $# -gt 0 ] && extra=",$*"
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"hook\":\"$hook\",\"session\":\"${CLAUDE_SESSION_ID:-$$}\",\"duration_ms\":$duration,\"result\":\"$result\"$extra}" \
    >> "$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
}
```

**Cross-session intelligence:** `retrieve-context.sh` reads recent logs to find frequently-activated rooms and feeds them as hints into the Stage 1 prompt template.

**Gitignore:** `.hook-log/` added to `~/workspace/.gitignore`.

---

## Hook-by-Hook Changes

### retrieve-context.sh (Rewrite)

**Changes:**
1. Read prompt templates from `~/workspace/workflows/hooks/retrieve-context/`
2. Session cache: skip retrieval if prompt overlaps >60% with last prompt's words
3. Frequency-weighted room hints from hook log (last 7 days)
4. First-prompt deep retrieval, subsequent prompts lightweight topic-shift check
5. Write to shared state (rooms activated, prompt words)
6. Log every invocation to hook log

**Cache logic:**

```bash
LAST_WORDS=$(read_state '.retrieve.last_prompt_words // ""')
if [ -n "$LAST_WORDS" ]; then
  OVERLAP=$(comm -12 <(echo "$PROMPT" | tr ' ' '\n' | sort -u) \
                      <(echo "$LAST_WORDS" | tr ' ' '\n' | sort -u) | wc -l)
  TOTAL=$(echo "$PROMPT" | wc -w)
  RATIO=$((OVERLAP * 100 / TOTAL))
  [ "$RATIO" -gt 60 ] && exit 0
fi
```

**Frequency hints:**

```bash
FREQ=$(cat "$LOG_DIR"/*.jsonl 2>/dev/null | \
  jq -r 'select(.hook == "retrieve-context" and .rooms_activated != null) | .rooms_activated[]' | \
  sort | uniq -c | sort -rn | head -5 | awk '{print $2 " (" $1 " sessions)"}')
```

### persist-session.sh (Rewrite)

**Changes:**
1. Read extraction prompt from `~/workspace/workflows/hooks/persist-session/extract-summary.md`
2. Enrich Haiku context with shared state (topic, repos_touched, tools_used, errors_seen)
3. Unified output format: include `what_worked`, `what_didnt_work`, `not_tried` fields
4. Sanitize all YAML frontmatter values (quote and escape)
5. Log to hook log

**Enriched extraction:** The template receives `{{TOPIC}}`, `{{REPOS_TOUCHED}}`, `{{TOOLS_USED}}`, `{{ERRORS_SEEN}}`, `{{GOAL_STATUS}}` from shared state, giving Haiku a richer picture beyond raw transcript.

### extract-instincts.sh (Upgrade)

**Changes:**
1. Read extraction prompt from `~/workspace/workflows/hooks/extract-instincts/extract-learnings.md`
2. Confidence gate: only write learnings with confidence >= 3
3. Deduplication: compare keywords against existing files in `~/.claude/skills/learned/`
4. Expiry: add `# expires: YYYY-MM-DD` (30 days) to each file
5. Log to hook log

**Dedup check:**

```bash
for existing in ~/.claude/skills/learned/"$SCOPE"/*.md; do
  [ -f "$existing" ] || continue
  EXISTING_KW=$(grep "^# keywords:" "$existing" | sed 's/^# keywords: //')
  OVERLAP=$(comm -12 <(echo "$KEYWORDS" | tr ',' '\n' | sort) \
                      <(echo "$EXISTING_KW" | tr ',' '\n' | sort) | wc -l)
  TOTAL=$(echo "$KEYWORDS" | tr ',' '\n' | wc -l)
  [ $((OVERLAP * 100 / TOTAL)) -gt 70 ] && SKIP=true
done
```

### check-goals.sh (Minor)

**Changes:**
1. Write `goal_status` to shared state after determining status
2. Log to hook log

### write-session-state.sh (Upgrade)

**Changes:**
1. Read `goal_status` from shared state (written by check-goals.sh)
2. Read extraction prompt from `~/workspace/workflows/hooks/write-session-state/handoff-document.md`
3. Include goal outcome in handoff document
4. Log to hook log

### validate-bash.sh (Upgrade)

**Changes:**
1. Fix suggestions from template file (`~/workspace/workflows/hooks/validate-bash/alternatives.md`)
2. Write `repos_touched` to shared state (from git remote in cwd)
3. Log blocked commands to hook log

**Alternatives table:**

```markdown
<!-- ~/workspace/workflows/hooks/validate-bash/alternatives.md -->
| Blocked pattern | Suggested alternative |
|---|---|
| `git push --force` to main/master | `git push origin <branch>` or `git push --force-with-lease` |
| `sops -e` from /tmp | Copy file to repo first, then `sops -e --in-place` |
| `cargo build` without musl (VM) | `cargo build --target x86_64-unknown-linux-musl` |
```

### validate-manifest.sh (Upgrade)

**Changes:**
1. Include securityContext boilerplate in warning output
2. Log to hook log

### validate-rust.sh (Upgrade)

**Changes:**
1. Emit first error only (not full wall)
2. Write `errors_seen++` to shared state
3. Log to hook log

### check-loop.sh (Rewrite)

**Changes:**
1. Fuzzy matching: normalize commands by stripping arguments before hashing
2. Failure-retry detection: track exit codes, warn after 3 consecutive failures
3. Escalation: 5 reps = warn, 8 = suggest stopping, 12 = recommend systematic-debugging skill
4. Write loop count and errors to shared state
5. Log to hook log

### report-activity.sh (Upgrade)

**Changes:**
1. Physical host mode: log activity to hook log (no API call)
2. VM mode: unchanged (POST to claude-worker API)

---

## Stop Chain Reorder

**Old:**
```
check-goals.sh → persist-session.sh → extract-instincts.sh → write-session-state.sh
```

**New:**
```
persist-session.sh → extract-instincts.sh → check-goals.sh → write-session-state.sh
```

**Rationale:** Session records and instincts are written while transcript is fresh, before check-goals can potentially block for 5 minutes. write-session-state runs last and reads goal_status from shared state (written by check-goals).

**mcp.nix:**

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

---

## File Inventory

### New files (workspace)

```
~/workspace/workflows/hooks/INDEX.md
~/workspace/workflows/hooks/CONTEXT.md
~/workspace/workflows/hooks/retrieve-context/stage1-room-selection.md
~/workspace/workflows/hooks/retrieve-context/stage2-summarize.md
~/workspace/workflows/hooks/persist-session/extract-summary.md
~/workspace/workflows/hooks/extract-instincts/extract-learnings.md
~/workspace/workflows/hooks/write-session-state/handoff-document.md
~/workspace/workflows/hooks/validate-bash/alternatives.md
~/workspace/.gitignore  (add .hook-log/)
```

### New files (claude-code-skills)

```
~/claude-code-skills/hooks/lib/state.sh
~/claude-code-skills/hooks/lib/log.sh
```

### Modified files (claude-code-skills)

```
~/claude-code-skills/hooks/retrieve-context.sh  (rewrite)
~/claude-code-skills/hooks/persist-session.sh   (rewrite)
~/claude-code-skills/hooks/extract-instincts.sh (upgrade)
~/claude-code-skills/hooks/write-session-state.sh (upgrade)
~/claude-code-skills/hooks/check-goals.sh       (minor — state write)
~/claude-code-skills/hooks/validate-bash.sh     (upgrade — suggestions + state)
~/claude-code-skills/hooks/validate-manifest.sh (upgrade — boilerplate + log)
~/claude-code-skills/hooks/validate-rust.sh     (upgrade — first-error + state + log)
~/claude-code-skills/hooks/check-loop.sh        (rewrite)
~/claude-code-skills/hooks/report-activity.sh   (upgrade — physical host log)
```

### Modified files (nixos-config)

```
~/nixos-config/modules/programs/cli/claude-code/mcp.nix  (Stop chain reorder)
```

---

## Success Criteria

1. `retrieve-context.sh` fires once per topic, not once per prompt — Haiku calls drop from N to ~1-2 per session
2. Hook log shows structured entries for every hook invocation — `cat ~/workspace/.hook-log/$(date +%Y-%m-%d).jsonl | jq .`
3. Stop chain completes with session record written BEFORE check-goals blocks
4. Prompt templates editable in Obsidian without code changes
5. `extract-instincts.sh` only writes learnings with confidence >= 3
6. `validate-bash.sh` includes fix suggestions when blocking
7. `check-loop.sh` detects failure-retry patterns, not just exact repeats
8. Cross-session room frequency data visible in hook log — `jq 'select(.hook=="retrieve-context")' ~/workspace/.hook-log/*.jsonl`
