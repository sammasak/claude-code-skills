#!/usr/bin/env bash
# PostToolUse Write|Edit hook — Nix file validator
# After any Write or Edit to a .nix file, run nix-instantiate --parse to catch
# syntax errors immediately, surfacing the first error as feedback to Claude.
# Never blocks (PostToolUse cannot block). Parse-only: no evaluation, no network.

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
  *.nix) ;;
  *)
    ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
    log_hook "validate-nix" "skipped" "$ELAPSED" 2>/dev/null || true
    exit 0
    ;;
esac

if [ -z "$FILE" ] || [ ! -f "$FILE" ] || ! command -v nix-instantiate >/dev/null 2>&1; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-nix" "skipped" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

set +e
OUTPUT=$(nix-instantiate --parse "$FILE" 2>&1 >/dev/null)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  RESULT="ok"
else
  RESULT="error"
  inc_state 'errors_seen' 2>/dev/null || true
  FIRST_ERROR=$(echo "$OUTPUT" | grep -m1 "error" || echo "$OUTPUT" | head -1)
  echo "Nix parse failed: $FIRST_ERROR" >&2
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "validate-nix" "$RESULT" "$ELAPSED" 2>/dev/null || true

exit 0
