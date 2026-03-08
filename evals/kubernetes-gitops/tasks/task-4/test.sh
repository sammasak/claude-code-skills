#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/kustomization.yaml"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

if ! yq eval '.' "$OUTPUT" > /dev/null 2>&1; then echo "FAIL: invalid YAML"; exit 1; fi

KIND=$(yq eval '.kind' "$OUTPUT")
if [[ "$KIND" != "Kustomization" ]]; then echo "FAIL: kind must be Kustomization, got $KIND"; exit 1; fi

# Must have prune: true
PRUNE=$(yq eval '.spec.prune' "$OUTPUT")
if [[ "$PRUNE" != "true" ]]; then echo "FAIL: spec.prune must be true"; exit 1; fi

# Must have dependsOn infrastructure
if ! yq eval '.spec.dependsOn[].name' "$OUTPUT" | grep -q "infrastructure"; then
    echo "FAIL: must depend on infrastructure"
    exit 1
fi

# Must have SOPS decryption config
if ! yq eval '.spec.decryption.provider' "$OUTPUT" | grep -qi "sops"; then
    echo "FAIL: must have SOPS decryption provider"
    exit 1
fi

# Must reference the sops-age secret
if ! grep -q "sops-age" "$OUTPUT"; then
    echo "FAIL: must reference sops-age secret"
    exit 1
fi

echo "PASS"
exit 0
