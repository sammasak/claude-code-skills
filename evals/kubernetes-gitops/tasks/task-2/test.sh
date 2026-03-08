#!/usr/bin/env bash
# Grader for task-2: HelmRelease manifest correctness
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/helmrelease.yaml"

if [[ ! -f "$OUTPUT" ]]; then
    echo "FAIL: $OUTPUT not found"
    exit 1
fi

# Check YAML is valid
if ! yq eval '.' "$OUTPUT" > /dev/null 2>&1; then
    echo "FAIL: invalid YAML"
    exit 1
fi

# Must be HelmRelease kind
KIND=$(yq eval '.kind' "$OUTPUT")
if [[ "$KIND" != "HelmRelease" ]]; then
    echo "FAIL: kind must be HelmRelease, got $KIND"
    exit 1
fi

# Must use correct API version (v2 is GA)
API=$(yq eval '.apiVersion' "$OUTPUT")
if ! echo "$API" | grep -q "helm.toolkit.fluxcd.io"; then
    echo "FAIL: apiVersion must be helm.toolkit.fluxcd.io/v2, got $API"
    exit 1
fi

# Must use semver range not floating tag
CHART_VERSION=$(yq eval '.spec.chart.spec.version' "$OUTPUT")
if echo "$CHART_VERSION" | grep -q "latest\|^v1\.16\.0$"; then
    echo "FAIL: must use semver range (e.g. '1.16.x' or '>=1.16.0 <1.17.0'), got $CHART_VERSION"
    exit 1
fi

# Must have remediation retries
RETRIES=$(yq eval '.spec.install.remediation.retries // .spec.upgrade.remediation.retries' "$OUTPUT")
if [[ -z "$RETRIES" || "$RETRIES" == "null" ]]; then
    echo "FAIL: missing remediation retries"
    exit 1
fi

# Must have drift detection
DRIFT=$(yq eval '.spec.driftDetection.mode' "$OUTPUT")
if [[ "$DRIFT" != "enabled" && "$DRIFT" != "warn" ]]; then
    echo "FAIL: driftDetection.mode must be 'enabled' or 'warn', got '$DRIFT'"
    exit 1
fi

echo "PASS"
exit 0
