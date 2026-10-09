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

# Per physical line: strip quoted segments (both styles) so a command merely
# CONTAINING the literal text (an echo, a commit message, a grep pattern) is
# not blocked, and quotes spanning lines cannot poison the whole command.
# [^|&;]* keeps the match inside the invocation; flags must be their own
# token so a branch named wip-f cannot trip the short flag.
while IFS= read -r LINE; do
  CODE=$(echo "$LINE" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
  if echo "$CODE" | grep -qE "git push[^|&;]*(--force([^-]|$)|[[:space:]]-f([[:space:]]|$))"; then
    block "force push is not allowed; revert with a new commit or push a branch."
  fi
  if echo "$CODE" | grep -qE "sops[^|&;]*(-e|encrypt)[^|&;]*/tmp/"; then
    block "SOPS encrypt from /tmp is unsafe; write plaintext to the repo path, then sops -e --in-place."
  fi
done <<< "$CMD"

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
