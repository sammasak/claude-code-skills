#!/usr/bin/env bash
# PostToolUse Write|Edit hook — shell script validator
# After any Write or Edit to a .sh/.bash file, run shellcheck (warning severity)
# and surface the first finding as feedback to Claude.
# Never blocks (PostToolUse cannot block). Skips silently if shellcheck is absent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

FILE=$(hook_file_path)

case "$FILE" in
  *.sh | *.bash) ;;
  *)
    ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
    log_hook "validate-shell" "skipped" "$ELAPSED" 2>/dev/null || true
    exit 0
    ;;
esac

if [ -z "$FILE" ] || [ ! -f "$FILE" ] || ! command -v shellcheck >/dev/null 2>&1; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-shell" "skipped" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

set +e
OUTPUT=$(shellcheck --severity=warning --format=gcc "$FILE" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  RESULT="ok"
else
  RESULT="error"
  inc_state 'errors_seen' 2>/dev/null || true
  COUNT=$(echo "$OUTPUT" | grep -c . || true)
  FIRST=$(echo "$OUTPUT" | head -1)
  echo "shellcheck: $COUNT finding(s), first: $FIRST" >&2
  echo "Run \`shellcheck $FILE\` for full output." >&2
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "validate-shell" "$RESULT" "$ELAPSED" 2>/dev/null || true

# PostToolUse exit 2 feeds stderr to the model without blocking; exit 0 doesn't.
[ "$RESULT" = "error" ] && exit 2
exit 0
