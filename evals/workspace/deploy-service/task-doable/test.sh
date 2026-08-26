#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/plan.md"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: plan.md not found at $OUTPUT"
    exit 1
fi

# Stage 1: npm run build must precede buildah
if ! grep -q "npm run build" "$OUTPUT"; then
    echo "FAIL: Stage 1 must include 'npm run build' for doable"
    exit 1
fi

if ! grep -q "buildah build" "$OUTPUT"; then
    echo "FAIL: Stage 1 must include 'buildah build'"
    exit 1
fi

if ! grep -q "\-\-isolation=chroot" "$OUTPUT"; then
    echo "FAIL: buildah build must use --isolation=chroot"
    exit 1
fi

# Stage 2: buildah push with authfile
if ! grep -q "buildah push" "$OUTPUT"; then
    echo "FAIL: Stage 2 must include 'buildah push' for doable"
    exit 1
fi

if ! grep -q "\-\-authfile" "$OUTPUT"; then
    echo "FAIL: buildah push must use --authfile (not hardcoded credentials)"
    exit 1
fi

# Stage ordering: push must precede kubectl rollout
PUSH_LINE=$(grep -n "buildah push" "$OUTPUT" | head -1 | cut -d: -f1)
ROLLOUT_LINE=$(grep -n "kubectl rollout" "$OUTPUT" | head -1 | cut -d: -f1)

if [[ -z "$PUSH_LINE" || -z "$ROLLOUT_LINE" ]]; then
    echo "FAIL: both 'buildah push' and 'kubectl rollout' must be present"
    exit 1
fi
if [[ "$PUSH_LINE" -gt "$ROLLOUT_LINE" ]]; then
    echo "FAIL: buildah push (line $PUSH_LINE) must precede kubectl rollout (line $ROLLOUT_LINE)"
    exit 1
fi

# Stage 3: correct namespace
if ! grep -q "\-n doable" "$OUTPUT"; then
    echo "FAIL: kubectl rollout must use namespace '-n doable'"
    exit 1
fi

# workstation-api commands must NOT appear
if grep -q "just release" "$OUTPUT"; then
    echo "FAIL: 'just release' is for workstation-api only, not doable"
    exit 1
fi

# Stage 4: verification step present
if ! grep -qiE "curl|verify|stage 4" "$OUTPUT"; then
    echo "FAIL: Stage 4 verification step required"
    exit 1
fi

echo "PASS"
exit 0
