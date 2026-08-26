#!/usr/bin/env bash
# Shared session state — read/write JSON file scoped to CLAUDE_SESSION_ID.
# Source this file from any hook: source "$(dirname "$0")/lib/state.sh"
#
# Schema v2: adds schema_version field; upgrade_state() migrates v1 files.

STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"
STATE_SCHEMA_VERSION=2

init_state() {
  if [ -f "$STATE_FILE" ]; then
    upgrade_state
    return
  fi
  cat > "$STATE_FILE" << STATEEOF
{
  "schema_version": ${STATE_SCHEMA_VERSION},
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

# Migrate v1 state files (missing schema_version) to current schema version.
upgrade_state() {
  local ver
  ver=$(jq -r '.schema_version // 1' "$STATE_FILE" 2>/dev/null || echo "1")
  if [ "$ver" -lt "$STATE_SCHEMA_VERSION" ] 2>/dev/null; then
    update_state ".schema_version = ${STATE_SCHEMA_VERSION}"
  fi
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
