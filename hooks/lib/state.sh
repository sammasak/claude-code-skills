#!/usr/bin/env bash
# Shared session state — read/write JSON file scoped to CLAUDE_SESSION_ID.
# Source this file from any hook: source "$(dirname "$0")/lib/state.sh"

STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"

init_state() {
  [ -f "$STATE_FILE" ] && return
  cat > "$STATE_FILE" << STATEEOF
{
  "session_id": "${CLAUDE_SESSION_ID:-$$}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prompt_count": 0,
  "retrieve": {
    "rooms_activated": [],
    "last_activated_at": null,
    "last_prompt_words": "",
    "context_injected": false
  },
  "repos_touched": [],
  "tools_used": {},
  "errors_seen": 0,
  "loop_count": 0,
  "goal_status": null
}
STATEEOF
}

read_state() {
  jq -r "$1" "$STATE_FILE" 2>/dev/null
}

update_state() {
  local tmp
  tmp=$(mktemp)
  if jq "$1" "$STATE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
  fi
}

inc_state() {
  update_state ".$1 = (.$1 // 0) + 1"
}
