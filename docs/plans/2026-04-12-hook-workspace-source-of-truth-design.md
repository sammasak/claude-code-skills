# Hook Architecture v3 — Workspace as Source of Truth + Enterprise Telemetry

**Date:** 2026-04-12
**Status:** Approved
**Extends:** `2026-03-31-hook-architecture-v2-design.md`
**Repos:** `~/claude-code-skills`, `~/workspace`, `~/nixos-config`

## Problem

v2 moved Haiku prompt templates into `~/workspace/workflows/hooks/`. The bash logic — the
control flow, API calls, git operations, decisions — is still embedded in
`~/claude-code-skills/hooks/*.sh`. This means:

1. **Any behavior change requires a Nix rebuild and re-deploy** — even simple logic tweaks.
2. **claude-code-skills owns semantics** it shouldn't — the "what" (commit tagging strategy,
   Loki label schema, vault entry format) is mixed with the "how" (hook lifecycle wiring).
3. **No enterprise-grade telemetry** — goal outcomes are invisible to Prometheus/Loki/Grafana,
   GH commits are unlinked to goals, knowledge vault is not written from VMs.

## Solution: v3 — Workspace Owns Logic, claude-code-skills Owns Wiring

**Principle:** claude-code-skills hooks become 5–15 line dispatchers. All behavior lives in
`~/workspace/workflows/hooks/<name>/run.sh` files, editable without touching Nix.

### Layer Split

```
~/workspace/workflows/hooks/<name>/   ← ALL logic (bash run.sh + prompts + CONTEXT.md docs)
~/claude-code-skills/hooks/<name>.sh  ← wiring only (env setup, sourcing, exit codes)
```

**claude-code-skills hook template:**
```bash
#!/usr/bin/env bash
# <name> — Stop/PreToolUse/PostToolUse dispatcher
# Delegates all logic to workspace workflow.
WORKSPACE="${WORKSPACE:-$HOME/workspace}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
source "$WORKSPACE/workflows/hooks/<name>/run.sh"
```

The workspace `run.sh` handles everything else and produces the correct exit code.

### What Moves Where

| Hook | Action | Reason |
|------|--------|--------|
| `check-goals.sh` | Move logic → workspace | Rich behavior — phases, review, goal loop |
| `retrieve-context.sh` | Move logic → workspace | Prompts already there; bash logic follows |
| `persist-session.sh` | Move logic → workspace | Prompts already there; bash logic follows |
| `extract-instincts.sh` | Move logic → workspace | Prompts already there; bash logic follows |
| `write-session-state.sh` | Move logic → workspace | VM handoff logic is meaningful docs |
| `report-activity.sh` | Move logic → workspace | Activity mapping rules are valuable as docs |
| `validate-bash.sh` | Keep in claude-code-skills | Pure plumbing — block rules are Claude Code-specific |
| `validate-manifest.sh` | Keep in claude-code-skills | Thin yq wrapper, no workspace-level logic |
| `validate-rust.sh` | Keep in claude-code-skills | Thin cargo check wrapper |
| `check-loop.sh` | Keep in claude-code-skills | Detection logic is Claude Code session-specific |

Migration is incremental — hooks move to workspace when they are touched, not all at once.

---

## New Feature: Enterprise Telemetry (agent-telemetry workflow)

A single new workflow `~/workspace/workflows/hooks/agent-telemetry/` replaces four planned
hooks. It fires in the Stop chain after `check-goals.sh` reaches Phase 4 (clean exit).
It is VM-only (guards on `goals.json` existence).

### Stages (in order)

```
agent-telemetry/run.sh
  ├── 1. tag-commits     sync  <3s   — git trailer on commits made this session
  ├── 2. push-metrics    sync  <5s   — Prometheus Pushgateway counters
  ├── 3. emit-loki       async       — structured log batch to Loki
  └── 4. write-vault     async       — session note + git push to workspace repo
```

Total sync budget: ~8s. Async stages fire in background and don't delay Claude exit.

### Stage 1: tag-commits

**Goal:** Every commit made during a goal session carries a `Goal-Id:` git trailer so the
work is traceable back to the goal that produced it.

**Implementation:**
- Read `WORKER_HOME/goals.json` — get current goal ID and `started_at` timestamp
- Run `git log --format="%H %s" --since="<started_at>"` in the workspace directory
- For each commit that lacks a `Goal-Id:` trailer, amend it:
  ```bash
  git commit --amend --no-edit --trailer "Goal-Id: <id>"
  ```
- Only amend unpushed commits (check `git status --short --branch`). If already pushed,
  append a note to the goal result instead — never force-push.
- Log amended commit SHAs to shared state.

**Skips:** If no commits since goal start, exits cleanly with no-op log.

### Stage 2: push-metrics

**Goal:** Prometheus counters for agent activity, queryable in Grafana, alertable.

**Pushgateway URL:** read from `PUSHGATEWAY_URL` env var (set in VM `.env`, sourced from
the claude-worker-bootstrap SOPS secret). Default: `http://pushgateway.monitoring.svc:9091`.

**Metrics pushed (text exposition format):**

```
# HELP agent_goals_total Total goals processed by claude-worker agents
# TYPE agent_goals_total counter
agent_goals_total{status="completed",vm="<hostname>",repo="<repo>"} 1

# HELP agent_goal_duration_seconds Time from goal start to completion
# TYPE agent_goal_duration_seconds gauge
agent_goal_duration_seconds{vm="<hostname>",goal_id="<id>"} <seconds>

# HELP agent_review_score_last Score assigned during self-review (0-10)
# TYPE agent_review_score_last gauge
agent_review_score_last{vm="<hostname>",goal_id="<id>"} <score>

# HELP agent_hook_calls_total Total hook invocations this session
# TYPE agent_hook_calls_total counter
agent_hook_calls_total{hook="<name>",vm="<hostname>"} <count>
```

Labels use `vm=$(hostname)`, `repo` from `repos_touched` in shared state, `goal_id` from
goals.json. All labels sanitized (alphanumeric + underscore only).

**Method:** Single `curl` POST to `/metrics/job/claude-worker/instance/<hostname>` with
text exposition body. Times out after 4s. Failure is logged but never blocks.

### Stage 3: emit-loki (async)

**Goal:** Structured audit log of every goal in Grafana/Loki, queryable with LogQL.

**Loki push URL:** read from `LOKI_URL` env var. Default: `http://loki.monitoring.svc:3100`.

**Log stream label set:**
```json
{"job": "claude-worker", "vm": "<hostname>", "goal_id": "<id>"}
```

**Entries pushed (one per completed goal):**
```json
{
  "goal_id": "<id>",
  "goal": "<text>",
  "status": "done",
  "review_score": 9,
  "review_note": "...",
  "duration_s": 847,
  "repos_touched": ["homelab-gitops", "nixos-config"],
  "tools_used": {"Bash": 42, "Write": 8, "Edit": 15},
  "commits_tagged": ["abc123", "def456"],
  "hook": "agent-telemetry",
  "vm": "<hostname>"
}
```

**Method:** Background subshell — `(curl ... &)`. Loki push API `/loki/api/v1/push`.
Timestamp is current epoch nanoseconds. Failure is silently swallowed (observability
should not break the agent).

### Stage 4: write-vault (async)

**Goal:** Every completed goal produces a session note in `~/workspace/sessions/ai-sessions/`
committed and pushed, so the vault is a searchable audit trail of all agent work.

**Format:** Standard AI session note (knowledge-vault skill schema):
```markdown
---
date: YYYY-MM-DD
type: ai-session
project: <repo or "multi">
goal: "<goal text>"
outcome: "<review_note>"
review_score: <0-10>
vm: <hostname>
goal_id: <id>
commits: [<sha>, ...]
repos: [<repo>, ...]
---

# <goal text>

## Outcome
<review_note>

## Work done
<summary from goals.json result field>

## Repos touched
<list>

## Commits
<list with short sha + subject>
```

**Method:** Background subshell:
1. Generate note from goals.json + shared state
2. Write to `~/workspace/sessions/ai-sessions/YYYY-MM-DD-<goal-id-slug>.md`
3. `git -C ~/workspace add sessions/ai-sessions/<file> && git commit -m "ai-session: <goal slug>"`
4. `git -C ~/workspace push origin main`

**Auth:** VM has git configured with `GH_TOKEN` credential helper (already wired in
claude-worker.nix). Push to `sammasak/workspace` (private repo) works via HTTPS + token.

**Skips:** If `~/workspace/.git` not found or push fails, logs warning to hook log and exits
cleanly — never blocks the Stop chain.

---

## Hook Chain After v3

```
Stop hook chain (VM):
  check-goals.sh              thin dispatcher → workspace/workflows/hooks/check-goals/run.sh
  write-session-state.sh      thin dispatcher → workspace/workflows/hooks/write-session-state/run.sh
  agent-telemetry.sh          NEW — thin dispatcher → workspace/workflows/hooks/agent-telemetry/run.sh
                                  stage 1: tag-commits   (sync)
                                  stage 2: push-metrics  (sync)
                                  stage 3: emit-loki     (async)
                                  stage 4: write-vault   (async)

Stop hook chain (physical host, unchanged):
  persist-session.sh          thin dispatcher → workspace/workflows/hooks/persist-session/run.sh
  extract-instincts.sh        thin dispatcher → workspace/workflows/hooks/extract-instincts/run.sh
```

---

## Delivery

New hooks follow existing delivery path:
1. Add `agent-telemetry.sh` to `~/claude-code-skills/hooks/`
2. Wire in `nixos-config/modules/programs/cli/claude-code/mcp.nix` (Stop hook array)
3. `cd ~/nixos-config && nix flake update claude-code-skills && nixos-rebuild switch`
4. New VMs automatically get it via Home Manager; existing VMs get it on next image rebuild

`PUSHGATEWAY_URL` and `LOKI_URL` added to the claude-worker-bootstrap SOPS secret so VMs
receive them in `.env` via cloud-init.

---

## Non-Goals

- No GitHub issue creation or PR opening (out of scope — commit tagging is sufficient traceability)
- No real-time Loki streaming during goal execution (only at completion; `report-activity.sh` handles real-time)
- No Tempo traces (Loki structured logs serve the audit use case; tracing is a future effort)
- No migration of validate-bash / validate-manifest / validate-rust / check-loop (these stay in claude-code-skills)

---

## Success Criteria

- Grafana dashboard shows `agent_goals_total` counter incrementing after each goal completes
- Loki contains structured goal completion entries queryable by `{job="claude-worker"}`
- `~/workspace/sessions/ai-sessions/` gains a new entry for every completed VM goal
- Commits made during goals carry `Goal-Id:` trailers (unpushed only)
- Stop chain total latency increase: <8s sync, <0s perceived (async stages invisible)
- No behavioral change to existing hooks — additive only
