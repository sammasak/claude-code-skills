#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/error.rs"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must use thiserror
if ! grep -q "thiserror\|#\[derive.*Error" "$OUTPUT"; then
    echo "FAIL: must use thiserror for the error type"
    exit 1
fi

# Must define WorkspaceClientError enum
if ! grep -q "enum WorkspaceClientError\|enum.*ClientError\|enum.*Error" "$OUTPUT"; then
    echo "FAIL: must define a typed error enum"
    exit 1
fi

# Must have #[error(...)] attributes
if ! grep -q '#\[error(' "$OUTPUT"; then
    echo "FAIL: must use #[error(\"...\")] attributes on variants"
    exit 1
fi

# Must have #[from] for at least reqwest or serde
if ! grep -q '#\[from\]' "$OUTPUT"; then
    echo "FAIL: must use #[from] for automatic conversion from reqwest::Error or serde_json::Error"
    exit 1
fi

# Must cover all 4 failure modes (check for key words)
COVERAGE=0
grep -qi "transport\|reqwest\|http.*error\|network" "$OUTPUT" && COVERAGE=$((COVERAGE+1))
grep -qi "api.*error\|status\|server.*error\|response.*error" "$OUTPUT" && COVERAGE=$((COVERAGE+1))
grep -qi "deserializ\|serde\|parse\|json.*error" "$OUTPUT" && COVERAGE=$((COVERAGE+1))
grep -qi "invalid.*name\|dns\|label\|workspace.*name\|invalid.*workspace" "$OUTPUT" && COVERAGE=$((COVERAGE+1))

if [[ "$COVERAGE" -lt 3 ]]; then
    echo "FAIL: must cover at least 3 of the 4 failure modes (HTTP transport, API error, deserialization, invalid name), only found $COVERAGE"
    exit 1
fi

echo "PASS"
exit 0
