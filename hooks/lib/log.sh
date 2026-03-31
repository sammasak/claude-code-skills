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
