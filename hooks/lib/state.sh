#!/usr/bin/env bash
# Shared session state — read/write JSON file scoped to CLAUDE_SESSION_ID.
# Source this file from any hook: source "$(dirname "$0")/lib/state.sh"
#
# Schema v3: only fields a live hook writes (errors_seen, loop_count);
# upgrade_state() migrates older files.

STATE_SCHEMA_VERSION=3

init_state() {
  # Resolved here, not at source time: hooks learn the session id from stdin
  # (read_hook_input) after sourcing this file.
  STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"
  find /tmp -maxdepth 1 -name 'claude-hook-state-*.json' -mtime +2 -delete 2>/dev/null || true
  if [ -f "$STATE_FILE" ]; then
    upgrade_state
    return
  fi
  cat > "$STATE_FILE" << STATEEOF
{
  "schema_version": ${STATE_SCHEMA_VERSION},
  "session_id": "${CLAUDE_SESSION_ID:-$$}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "errors_seen": 0,
  "loop_count": 0
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
