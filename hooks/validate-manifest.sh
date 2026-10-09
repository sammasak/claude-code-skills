#!/usr/bin/env bash
# PostToolUse Write|Edit hook — Kubernetes manifest validator.
# YAML syntax via yq plus the cluster security baseline (same policy as
# agents/validate-k8s.md: CPU limits are optional, memory limits are not).
# Never blocks (PostToolUse cannot block).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))
RESULT="ok"

FILE=$(hook_file_path)

finish() {
  log_hook "validate-manifest" "$1" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
  exit 0
}

case "$FILE" in
  *.yaml | *.yml) ;;
  *) finish "skipped" ;;
esac
[ -f "$FILE" ] || finish "skipped"
command -v yq >/dev/null 2>&1 || finish "skipped"

if ! yq eval '.' "$FILE" >/dev/null 2>&1; then
  echo "Invalid YAML syntax in $FILE — check indentation before applying." >&2
  finish "warned"
fi

if yq eval '.kind' "$FILE" 2>/dev/null | grep -qiE "^(Deployment|StatefulSet|DaemonSet)$"; then
  for probe in seccompProfile allowPrivilegeEscalation "resources:"; do
    if ! grep -q "$probe" "$FILE"; then
      echo "Workload manifest $FILE is missing $probe (cluster baseline: runAsNonRoot, drop ALL caps, requests + memory limit; CPU limit optional)." >&2
      RESULT="warned"
    fi
  done
fi

finish "$RESULT"
