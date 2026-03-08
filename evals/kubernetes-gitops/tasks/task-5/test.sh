#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/image-automation.md"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must identify scan interval as root cause
if ! grep -qi "interval\|scan.*frequency\|not.*scanned\|2.*hour" "$OUTPUT"; then
    echo "FAIL: must identify stale scan interval as root cause"
    exit 1
fi

# Must include flux reconcile command to force scan
if ! grep -q "flux reconcile\|flux reconcile imagerepository\|flux reconcile image" "$OUTPUT"; then
    echo "FAIL: must include 'flux reconcile' command to force scan"
    exit 1
fi

# Must mention the interval field with 5m value
if ! grep -qE "interval.*5m|5m.*interval|5 minute" "$OUTPUT"; then
    echo "FAIL: must specify 5m interval"
    exit 1
fi

echo "PASS"
exit 0
