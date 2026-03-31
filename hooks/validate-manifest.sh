#!/usr/bin/env bash
# PostToolUse Write/Edit hook — Kubernetes manifest validator
# Checks YAML syntax for any .yaml file written by Claude.
# Outputs warnings to stdout (informational, does not block).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))
RESULT="ok"

FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")

emit_event() {
  local json="$1"
  curl -sf -X POST "${CLAUDE_WORKER_API:-http://localhost:4200}/events" \
    -H "Content-Type: application/json" \
    -d "$json" \
    --max-time 1 -o /dev/null 2>/dev/null || true
}

if [ -z "$FILE" ]; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-manifest" "skipped" "$ELAPSED" "\"reason\":\"no-file\"" 2>/dev/null || true
  exit 0
fi

# Only validate .yaml files
if ! echo "$FILE" | grep -qE '\.ya?ml$'; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-manifest" "skipped" "$ELAPSED" "\"file\":\"$(basename "$FILE")\",\"reason\":\"not-yaml\"" 2>/dev/null || true
  exit 0
fi

if [ ! -f "$FILE" ]; then
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-manifest" "skipped" "$ELAPSED" "\"file\":\"$(basename "$FILE")\",\"reason\":\"not-found\"" 2>/dev/null || true
  exit 0
fi

emit_event "{\"type\":\"file_op\",\"op\":\"${CLAUDE_TOOL_NAME:-Write}\",\"path\":$(echo "$FILE" | jq -Rs .)}"

# Check YAML syntax with yq
if yq eval '.' "$FILE" > /dev/null 2>&1; then
  echo "✓ YAML valid: $FILE"
else
  echo "WARNING: Invalid YAML syntax in $FILE — check indentation and syntax before applying."
  RESULT="warned"
fi

# Warn if it looks like a Kubernetes manifest missing security context
if yq eval '.kind' "$FILE" 2>/dev/null | grep -qiE "^Deployment$|^StatefulSet$|^DaemonSet$"; then
  if ! grep -q "seccompProfile" "$FILE"; then
    echo "WARNING: $FILE is a workload manifest missing seccompProfile in securityContext. Add: seccompProfile: {type: RuntimeDefault}"
    RESULT="warned"
  fi
  if ! grep -q "allowPrivilegeEscalation" "$FILE"; then
    echo "WARNING: $FILE is missing allowPrivilegeEscalation: false in container securityContext."
    RESULT="warned"
  fi
  if ! grep -q "resources:" "$FILE"; then
    echo "WARNING: $FILE is missing resource requests/limits."
    RESULT="warned"
  fi
  if [ "$RESULT" = "warned" ]; then
    echo "WARNING: Missing securityContext. Add to the container spec:" >&2
    echo "  securityContext:" >&2
    echo "    runAsNonRoot: true" >&2
    echo "    readOnlyRootFilesystem: true" >&2
    echo "    allowPrivilegeEscalation: false" >&2
  fi
fi

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "validate-manifest" "$RESULT" "$ELAPSED" "\"file\":\"$(basename "$FILE")\"" 2>/dev/null || true
exit 0
