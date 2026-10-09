#!/usr/bin/env bash
# PreToolUse Bash hook — danger blocker.
# Exit 2 + stderr BLOCKS the command and feeds the message back to Claude;
# exit 0 allows. --force-with-lease is deliberately not matched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

CMD=$(hook_command)
[ -z "$CMD" ] && exit 0

block() {
  echo "BLOCKED: $1" >&2
  log_hook "validate-bash" "blocked" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
  exit 2
}

# Single-quoted segments are stripped first so a command merely CONTAINING
# the literal text (an echo, a jq payload, a commit message) is not blocked;
# [^|&;]* keeps the match inside the push invocation itself.
CMD_CODE=$(echo "$CMD" | sed "s/'[^']*'//g")
if echo "$CMD_CODE" | grep -qE "git push[^|&;]*(--force([^-]|$)|-f\b)"; then
  block "force push is not allowed; revert with a new commit or push a branch."
fi

if echo "$CMD_CODE" | grep -qE "sops.*-e.*/tmp/|sops.*encrypt.*/tmp/"; then
  block "SOPS encrypt from /tmp is unsafe; write plaintext to the repo path, then sops -e --in-place."
fi

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
