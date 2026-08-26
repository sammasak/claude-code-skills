#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/run_strategy.rs"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must define a RunStrategy enum
if ! grep -q "enum RunStrategy" "$OUTPUT"; then
    echo "FAIL: must define RunStrategy enum"
    exit 1
fi

# Must have Always and Halted variants
if ! grep -q "Always" "$OUTPUT" || ! grep -q "Halted" "$OUTPUT"; then
    echo "FAIL: enum must have Always and Halted variants"
    exit 1
fi

# Must use serde rename_all PascalCase
if ! grep -q 'rename_all.*PascalCase\|PascalCase' "$OUTPUT"; then
    echo "FAIL: must use #[serde(rename_all = \"PascalCase\")] for correct JSON serialization"
    exit 1
fi

# Must use Default derive or serde default
if ! grep -qE '#\[default\]|Default' "$OUTPUT"; then
    echo "FAIL: must mark Halted as default (using #[default] or #[derive(Default)])"
    exit 1
fi

# Must NOT contain validate_run_strategy
if grep -q "validate_run_strategy" "$OUTPUT"; then
    echo "FAIL: must remove validate_run_strategy — the enum makes it unnecessary"
    exit 1
fi

echo "PASS"
exit 0
