#!/usr/bin/env bash
# PostToolUse Write|Edit hook — Rust file validator
# After any Write or Edit to a .rs file, find the Cargo workspace root
# and run cargo check --quiet, surfacing compile errors as feedback to Claude.
# Never blocks (PostToolUse cannot block). Only fires inside a Cargo workspace.

set -euo pipefail

FILE=$(echo "${CLAUDE_TOOL_INPUT:-{\}}" | jq -r '.file_path // ""' 2>/dev/null || echo "")

# Only for .rs files
case "$FILE" in
  *.rs) ;;
  *) exit 0 ;;
esac

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

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
[ -z "$CARGO_ROOT" ] && exit 0

# Find cargo binary (rustup managed)
CARGO=""
if command -v cargo >/dev/null 2>&1; then
  CARGO=$(command -v cargo)
elif [ -x "$HOME/.cargo/bin/cargo" ]; then
  CARGO="$HOME/.cargo/bin/cargo"
else
  exit 0
fi

# Run cargo check — quiet suppresses Compiling lines, leaving only errors
# Use set +e around the capture so a non-zero exit doesn't trigger set -e abort
set +e
OUTPUT=$("$CARGO" check --quiet --manifest-path "$CARGO_ROOT/Cargo.toml" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ cargo check passed: $(basename "$FILE")"
else
  echo "cargo check FAILED after editing $FILE:"
  echo "$OUTPUT"
  echo ""
  echo "Fix the compile errors above before continuing."
fi

exit 0
