#!/usr/bin/env bash
# Hook log — append-only JSONL for observability and cross-session intelligence.
# Source this file from any hook: source "$(dirname "$0")/lib/log.sh"
#
# Usage: log_hook <hook> <result> <duration_ms> [extras_json]
#   extras_json — optional JSON object string of hook-specific fields, e.g.
#                 '{"file":"foo.txt","count":3}'
#   All fields (hook, session, duration_ms, result, ts) are always present.

HOOK_LOG_DIR="${HOME}/workspace/.hook-log"

log_hook() {
  local hook="$1" result="$2" duration_ms="$3"
  local extras="${4:-}"

  [ -d "${HOME}/workspace" ] || return 0
  mkdir -p "$HOOK_LOG_DIR"

  # Build base entry; merge extras JSON object if provided
  local log_line
  if [ -n "$extras" ]; then
    log_line=$(jq -cn \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg hook "$hook" \
      --arg session "${CLAUDE_SESSION_ID:-$$}" \
      --argjson dur "$duration_ms" \
      --arg result "$result" \
      --argjson extras "$extras" \
      '{ts:$ts,hook:$hook,session:$session,duration_ms:$dur,result:$result} * $extras' \
      2>/dev/null)
  fi
  # Fallback to base-only if extras was absent or invalid JSON
  if [ -z "$log_line" ]; then
    log_line=$(jq -cn \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg hook "$hook" \
      --arg session "${CLAUDE_SESSION_ID:-$$}" \
      --argjson dur "$duration_ms" \
      --arg result "$result" \
      '{ts:$ts,hook:$hook,session:$session,duration_ms:$dur,result:$result}')
  fi
  printf '%s\n' "$log_line" >> "$HOOK_LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
}
