#!/usr/bin/env bash
# agent-telemetry — Stop hook dispatcher (VM only)
# Delegates all logic to ~/workspace/workflows/hooks/agent-telemetry/run.sh.
# Runs after write-session-state.sh in the Stop chain.
# Timeout: 60s (sync stages ~8s, async stages fire-and-forget).

WORKSPACE="${WORKSPACE:-$HOME/workspace}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true

RUN_SH="$WORKSPACE/workflows/hooks/agent-telemetry/run.sh"

if [ ! -f "$RUN_SH" ]; then
  log_hook "agent-telemetry" "skip-no-workflow" "0" 2>/dev/null || true
  exit 0
fi

bash "$RUN_SH"
