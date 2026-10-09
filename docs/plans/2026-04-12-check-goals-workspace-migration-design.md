# check-goals Workspace Migration — Design

**Date:** 2026-04-12
**Status:** Approved
**Extends:** `2026-04-12-hook-workspace-source-of-truth-design.md`
**Repos:** `~/claude-code-skills`, `~/workspace`

## Problem

`check-goals.sh` is the goal loop controller for claude-worker VMs. It contains ~150 lines of
4-phase bash logic embedded in `~/claude-code-skills/hooks/check-goals.sh`. Per Hook Architecture
v3, all behavior should live in `~/workspace/workflows/hooks/` so it can be edited without a Nix
rebuild. Only the thin wiring stays in claude-code-skills.

## Solution

Apply the same thin-dispatcher pattern already established for `agent-telemetry`:

```
~/workspace/workflows/hooks/check-goals/run.sh     ← all 4-phase logic (moved here)
~/claude-code-skills/hooks/check-goals.sh          ← thin dispatcher only (<20 lines)
```

### Dispatcher (`check-goals.sh`)

```bash
#!/usr/bin/env bash
# check-goals — Stop hook dispatcher
WORKSPACE="${WORKSPACE:-$HOME/workspace}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_SKILLS_LIB="$SCRIPT_DIR/lib"      # run.sh sources lib via this var
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
RUN_SH="$WORKSPACE/workflows/hooks/check-goals/run.sh"
if [ ! -f "$RUN_SH" ]; then exit 0; fi
bash "$RUN_SH"   # bash not source — prevents set option leakage
```

Key difference from agent-telemetry: `check-goals.sh` uses `log_hook`, `update_state`,
`read_state` from `lib/state.sh` and `lib/log.sh`. The dispatcher exports `CLAUDE_SKILLS_LIB`
so `run.sh` can source the libs with graceful fallback (`|| true`).

### run.sh (workspace)

The 4-phase logic moves verbatim. Only changes:
- Add `source "$CLAUDE_SKILLS_LIB/state.sh" 2>/dev/null || true` at the top
- Add `source "$CLAUDE_SKILLS_LIB/log.sh" 2>/dev/null || true` at the top
- `init_state 2>/dev/null || true` call preserved

The logic itself is unchanged — no behavior changes, pure migration.

### CONTEXT.md (workspace)

Documents:
- Purpose: Stop hook goal loop controller for claude-worker VMs
- The 4 phases and their exit conditions
- Key env vars: `CLAUDE_WORKER_HOME`, `CLAUDE_WORKER_API`, `REVIEW_TIMEOUT`
- Output format: JSON `{"decision": "block", "reason": "..."}` or exit 0

## Non-Goals

- No logic changes to the 4 phases
- No new orchestration features
- No changes to how goals.json is structured
- No changes to mcp.nix (check-goals.sh path unchanged)

## Success Criteria

- `~/workspace/workflows/hooks/check-goals/run.sh` contains the 4-phase logic
- `~/claude-code-skills/hooks/check-goals.sh` is a thin dispatcher (<20 lines)
- Existing hook behavior is identical — VMs continue to loop on pending goals
- Both files committed to their respective repos
