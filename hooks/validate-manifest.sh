#!/bin/bash
# PostToolUse Write/Edit hook — Kubernetes manifest validator
# Checks YAML syntax for any .yaml file written by Claude.
# Outputs warnings to stdout (informational, does not block).

FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // ""' 2>/dev/null || echo "")

if [ -z "$FILE" ]; then
  exit 0
fi

# Only validate .yaml files
if ! echo "$FILE" | grep -qE '\.ya?ml$'; then
  exit 0
fi

if [ ! -f "$FILE" ]; then
  exit 0
fi

# Check YAML syntax with yq
if yq eval '.' "$FILE" > /dev/null 2>&1; then
  echo "✓ YAML valid: $FILE"
else
  echo "WARNING: Invalid YAML syntax in $FILE — check indentation and syntax before applying."
fi

# Warn if it looks like a Kubernetes manifest missing security context
if yq eval '.kind' "$FILE" 2>/dev/null | grep -qiE "^Deployment$|^StatefulSet$|^DaemonSet$"; then
  if ! grep -q "seccompProfile" "$FILE"; then
    echo "WARNING: $FILE is a workload manifest missing seccompProfile in securityContext. Add: seccompProfile: {type: RuntimeDefault}"
  fi
  if ! grep -q "allowPrivilegeEscalation" "$FILE"; then
    echo "WARNING: $FILE is missing allowPrivilegeEscalation: false in container securityContext."
  fi
  if ! grep -q "resources:" "$FILE"; then
    echo "WARNING: $FILE is missing resource requests/limits."
  fi
fi
