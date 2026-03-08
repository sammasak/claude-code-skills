#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/fix.md"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must identify missing env var as root cause
if ! grep -qi "WORKSTATION_NAMESPACE\|environment variable\|env.*not set" "$OUTPUT"; then
    echo "FAIL: root cause must identify missing WORKSTATION_NAMESPACE env var"
    exit 1
fi

# Must include kubectl to apply fix (patch deployment or set env)
if ! grep -q "kubectl" "$OUTPUT"; then
    echo "FAIL: fix must include kubectl command"
    exit 1
fi

# Must NOT suggest deleting the pod as the fix (pod is ephemeral, fine to mention it restarts,
# but the actual fix is to the Deployment/env config)
if grep -qi "kubectl delete pod\|fix.*delete" "$OUTPUT"; then
    echo "FAIL: fix must address the Deployment env config, not just delete the pod"
    exit 1
fi

echo "PASS"
exit 0
