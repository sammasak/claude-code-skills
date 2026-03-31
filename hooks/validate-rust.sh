#!/usr/bin/env bash
# PostToolUse Write|Edit hook — Rust file validator
# After any Write or Edit to a .rs file, find the Cargo workspace root
# and run cargo check --quiet, surfacing compile errors as feedback to Claude.
# Never blocks (PostToolUse cannot block). Only fires inside a Cargo workspace.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

FILE=$(echo "${CLAUDE_TOOL_INPUT:-{\}}" | jq -r '.file_path // ""' 2>/dev/null || echo "")

# Only for .rs files
case "$FILE" in
  *.rs) ;;
  *)
    ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
    log_hook "validate-rust" "skipped" "$ELAPSED" 2>/dev/null || true
    exit 0
    ;;
esac

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-rust" "skipped" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

# Walk up directory tree to find Cargo.toml (workspace root)
DIR=$(dirname "$FILE")
CARGO_ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/Cargo.toml" ]; then
    CARGO_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

# No Cargo workspace found — stray .rs file, skip
if [ -z "$CARGO_ROOT" ]; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-rust" "skipped" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

# Find cargo binary (rustup managed)
CARGO=""
if command -v cargo >/dev/null 2>&1; then
  CARGO=$(command -v cargo)
elif [ -x "$HOME/.cargo/bin/cargo" ]; then
  CARGO="$HOME/.cargo/bin/cargo"
else
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-rust" "skipped" "$ELAPSED" 2>/dev/null || true
  exit 0
fi

# Run cargo check — quiet suppresses Compiling lines, leaving only errors
# Use set +e around the capture so a non-zero exit doesn't trigger set -e abort
set +e
OUTPUT=$("$CARGO" check --quiet --manifest-path "$CARGO_ROOT/Cargo.toml" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  RESULT="ok"
  echo "cargo check passed: $(basename "$FILE")"
else
  RESULT="error"
  inc_state 'errors_seen' 2>/dev/null || true

  # Show only the first error line instead of the full wall of output
  FIRST_ERROR=$(echo "$OUTPUT" | grep "^error" | head -1)
  if [ -n "$FIRST_ERROR" ]; then
    echo "Cargo check failed: $FIRST_ERROR" >&2
  else
    echo "Cargo check failed after editing $FILE" >&2
  fi
  echo "Run \`cargo check\` for full output." >&2
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "validate-rust" "$RESULT" "$ELAPSED" 2>/dev/null || true

exit 0
