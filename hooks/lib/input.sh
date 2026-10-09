#!/usr/bin/env bash
# Hook input contract: Claude Code delivers ONE JSON object on stdin
# (session_id, cwd, tool_input.*, ...). There is no CLAUDE_TOOL_INPUT env
# var — hooks that read it silently no-op, which is how the whole validator
# tier shipped dead. Source this, call read_hook_input first thing.

read_hook_input() {
  HOOK_INPUT=$(cat 2>/dev/null || true)
  CLAUDE_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
  [ -n "$CLAUDE_SESSION_ID" ] || CLAUDE_SESSION_ID="nosession"
  export CLAUDE_SESSION_ID
}

hook_file_path() { echo "${HOOK_INPUT:-}" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true; }
hook_command() { echo "${HOOK_INPUT:-}" | jq -r '.tool_input.command // ""' 2>/dev/null || true; }
