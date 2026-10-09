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

# Rule 1 — mentions are not invocations: balanced quoted CONTENT is stripped
# across the whole command (sed -z, so quotes spanning lines cannot poison
# later lines), then a push must sit at command position with the flag as its
# own token. Rule 2 — flags cannot hide in quotes: a real push invocation
# whose raw segment quotes a leading-dash argument is refused outright
# (nothing legitimate quotes flags to git push).
INVOC='(^|[|&;]|\$\()[[:space:]]*((env|command|sudo|nice)[[:space:]]+)*git[[:space:]]+push'
STRIPPED=$(echo "$CMD" | sed -z "s/'[^']*'//g; s/\"[^\"]*\"//g")
if echo "$STRIPPED" | grep -qE "${INVOC}[^|&;]*(--force([^-]|\$)|[[:space:]]-f([[:space:]]|\$))"; then
  block "force push is not allowed; revert with a new commit or push a branch."
fi
if echo "$CMD" | grep -qE "${INVOC}[^|&;]*[\"'][[:space:]]*-"; then
  block "quoted flags to git push are not allowed."
fi
if echo "$STRIPPED" | grep -qE "sops[^|&;]*(-e|encrypt)[^|&;]*/tmp/"; then
  block "SOPS encrypt from /tmp is unsafe; write plaintext to the repo path, then sops -e --in-place."
fi

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
