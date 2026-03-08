#!/usr/bin/env bash
# Grader for task-1: HelmRelease remediation
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/remediation.md"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: $OUTPUT not found"
    exit 1
fi

# Check that root cause mentions "resource already exists" or ownership
if ! grep -qi "already exists\|ownership\|imported\|annotation" "$OUTPUT"; then
    echo "FAIL: root cause diagnosis does not address resource ownership conflict"
    exit 1
fi

# Check that remediation includes a flux command (not just deleting namespace)
if ! grep -q "flux" "$OUTPUT"; then
    echo "FAIL: remediation does not use flux commands"
    exit 1
fi

# Check for force-adopt or --force flag approach (correct remediation)
if ! grep -qiE "force|adopt|suspend|resume" "$OUTPUT"; then
    echo "FAIL: remediation does not mention force/adopt or suspend+resume approach"
    exit 1
fi

# Ensure they are NOT recommending deleting the namespace
if grep -qi "delete.*namespace\|kubectl delete ns" "$OUTPUT"; then
    echo "FAIL: remediation incorrectly recommends deleting the namespace"
    exit 1
fi

echo "PASS"
exit 0
