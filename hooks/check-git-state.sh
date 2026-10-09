#!/usr/bin/env bash
# Stop hook — git state reporter
# At session stop, if the working directory is a git repo, print a one-line
# summary of anything that would strand work: dirty files, commits not pushed
# to upstream, or being behind upstream (per the last fetch — no network calls).
# Audience is the HUMAN in the transcript, not the model: always exits 0 and
# never blocks the Stop — exit 2 here would force the session to continue.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

if ! git -C "$PWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_hook "check-git-state" "skipped" "0" 2>/dev/null || true
  exit 0
fi

REPO=$(basename "$(git -C "$PWD" rev-parse --show-toplevel)")
BRANCH=$(git -C "$PWD" symbolic-ref --short -q HEAD || echo "detached")
DIRTY=$(git -C "$PWD" status --porcelain 2>/dev/null | grep -c . || true)

AHEAD=0
BEHIND=0
if UPSTREAM=$(git -C "$PWD" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
  COUNTS=$(git -C "$PWD" rev-list --left-right --count "HEAD...$UPSTREAM" 2>/dev/null || echo "0	0")
  AHEAD=$(echo "$COUNTS" | cut -f1)
  BEHIND=$(echo "$COUNTS" | cut -f2)
else
  UPSTREAM="(no upstream)"
fi

if [ "$DIRTY" -eq 0 ] && [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ] && [ "$UPSTREAM" != "(no upstream)" ]; then
  log_hook "check-git-state" "clean" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
  exit 0
fi

echo "git state [$REPO @ $BRANCH]: ${DIRTY} dirty, ${AHEAD} unpushed, ${BEHIND} behind ${UPSTREAM}"

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "check-git-state" "reported" "$ELAPSED" "{\"dirty\":$DIRTY,\"ahead\":$AHEAD,\"behind\":$BEHIND}" 2>/dev/null || true

exit 0
