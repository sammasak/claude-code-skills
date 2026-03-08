#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/workspace_name.rs"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must define WorkspaceName struct
if ! grep -q "struct WorkspaceName" "$OUTPUT"; then
    echo "FAIL: must define WorkspaceName struct"
    exit 1
fi

# Inner field must be private (no pub on the field)
# Check that the field inside the struct is not pub
if grep -A2 "struct WorkspaceName" "$OUTPUT" | grep -q "pub.*String\|pub("; then
    echo "FAIL: inner field must be private to enforce construction through validator"
    exit 1
fi

# Must have a new() or try_new() or from_str() constructor returning Result
if ! grep -qE "fn new|fn try_new|fn from_str" "$OUTPUT"; then
    echo "FAIL: must have a constructor returning Result"
    exit 1
fi

if ! grep -q "Result" "$OUTPUT"; then
    echo "FAIL: constructor must return Result"
    exit 1
fi

# Must implement AsRef<str> or Deref<Target=str>
if ! grep -qE "AsRef<str>|AsRef<String>|impl.*AsRef" "$OUTPUT"; then
    echo "FAIL: must implement AsRef<str> for ergonomic use"
    exit 1
fi

echo "PASS"
exit 0
