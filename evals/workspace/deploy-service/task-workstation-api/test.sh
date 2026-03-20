#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/plan.md"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: plan.md not found at $OUTPUT"
    exit 1
fi

# just release must be present
if ! grep -q "just release" "$OUTPUT"; then
    echo "FAIL: workstation-api must use 'just release' for build+push"
    exit 1
fi

# buildah push must NOT appear after just release (just release handles push internally)
RELEASE_LINE=$(grep -n "just release" "$OUTPUT" | head -1 | cut -d: -f1)
PUSH_LINES=$(grep -n "buildah push" "$OUTPUT" | wc -l)

if [[ "$PUSH_LINES" -gt 0 ]]; then
    FIRST_PUSH=$(grep -n "buildah push" "$OUTPUT" | head -1 | cut -d: -f1)
    if [[ "$FIRST_PUSH" -gt "$RELEASE_LINE" ]]; then
        echo "FAIL: buildah push must NOT appear after 'just release' (line $RELEASE_LINE) — just release handles push internally"
        exit 1
    fi
fi

# Must proceed to verification (kubectl or curl)
if ! grep -qiE "kubectl rollout|curl.*healthz|stage 4|verify" "$OUTPUT"; then
    echo "FAIL: must proceed to verification after just release"
    exit 1
fi

# Correct namespace
if grep -qi "\-n doable" "$OUTPUT"; then
    echo "FAIL: workstation-api uses namespace 'workstations', not 'doable'"
    exit 1
fi

# Health endpoint
if ! grep -q "healthz" "$OUTPUT"; then
    echo "FAIL: Stage 4 must verify workstation-api via /healthz endpoint"
    exit 1
fi

# npm run build must NOT appear (that's the doable build step)
if grep -q "npm run build" "$OUTPUT"; then
    echo "FAIL: 'npm run build' is for doable only — workstation-api uses 'just release'"
    exit 1
fi

echo "PASS"
exit 0
