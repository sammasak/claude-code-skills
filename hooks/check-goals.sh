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
