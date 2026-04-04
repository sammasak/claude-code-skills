#!/usr/bin/env bash
# PreToolUse Bash hook — musl enforcer + danger blocker
# Reads the proposed bash command from CLAUDE_TOOL_INPUT (JSON).
# Exits with code 2 + stderr message to BLOCK the command.
# Exits with code 0 to allow the command.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

CMD=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")

emit_event() {
  local json="$1"
  curl -sf -X POST "${CLAUDE_WORKER_API:-http://localhost:4200}/events" \
    -H "Content-Type: application/json" \
    -d "$json" \
    --max-time 1 -o /dev/null 2>/dev/null || true
}

ALT_FILE="$HOME/workspace/workflows/hooks/validate-bash/alternatives.md"
lookup_suggestion() {
  local pattern="$1"
  [ -f "$ALT_FILE" ] || return
  grep -i "$pattern" "$ALT_FILE" 2>/dev/null | head -1 | awk -F'|' '{print $3}' | xargs
}

if [ -z "$CMD" ]; then
  exit 0
fi

# Agent-specific rules: only enforce on claude-worker VMs
if [ -f "${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}/goals.json" ]; then
  # Block: cargo build without musl target
  # Rust binaries must be statically linked for container compatibility.
  if echo "$CMD" | grep -qE "cargo build|cargo test" && ! echo "$CMD" | grep -qE "musl|x86_64-unknown-linux-musl"; then
    SUGGESTION=$(lookup_suggestion "musl")
    echo "BLOCKED: Rust binaries must use --target x86_64-unknown-linux-musl for container compatibility.${SUGGESTION:+ Try: $SUGGESTION}" >&2
    ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
    log_hook "validate-bash" "blocked" "$ELAPSED" "\"command\":\"$(echo "$CMD" | head -c 100 | tr '"' "'")\"" 2>/dev/null || true
    exit 2
  fi

  # Block: buildah push without --authfile
  # The auth file is pre-configured — use it, don't call buildah login.
  if echo "$CMD" | grep -qE "buildah push" && ! echo "$CMD" | grep -q "authfile"; then
    SUGGESTION=$(lookup_suggestion "authfile")
    echo "BLOCKED: buildah push requires --authfile /var/lib/claude-worker/.config/containers/auth.json${SUGGESTION:+ Try: $SUGGESTION}" >&2
    ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
    log_hook "validate-bash" "blocked" "$ELAPSED" "\"command\":\"$(echo "$CMD" | head -c 100 | tr '"' "'")\"" 2>/dev/null || true
    exit 2
  fi
fi

# Universal rules: active everywhere
# Block: force push
if echo "$CMD" | grep -qE "git push.*(--force([^-]|$)|-f\b)"; then
  SUGGESTION=$(lookup_suggestion "force.push")
  echo "BLOCKED: force push to main is not allowed.${SUGGESTION:+ Try: $SUGGESTION}" >&2
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-bash" "blocked" "$ELAPSED" "\"command\":\"$(echo "$CMD" | head -c 100 | tr '"' "'")\"" 2>/dev/null || true
  exit 2
fi

# Block: SOPS encrypt from /tmp
if echo "$CMD" | grep -qE "sops.*-e.*/tmp/|sops.*encrypt.*/tmp/"; then
  SUGGESTION=$(lookup_suggestion "sops.*tmp")
  echo "BLOCKED: SOPS encrypt from /tmp is unsafe.${SUGGESTION:+ Try: $SUGGESTION}" >&2
  ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
  log_hook "validate-bash" "blocked" "$ELAPSED" "\"command\":\"$(echo "$CMD" | head -c 100 | tr '"' "'")\"" 2>/dev/null || true
  exit 2
fi

# Track repos_touched
REPO_NAME=$(git -C "${TOOL_CWD:-.}" remote get-url origin 2>/dev/null | sed 's|.*/||;s|\.git$||')
if [ -n "$REPO_NAME" ]; then
  update_state ".repos_touched = (.repos_touched + [\"$REPO_NAME\"] | unique)" 2>/dev/null || true
fi

emit_event "{\"type\":\"tool_start\",\"tool\":\"bash\",\"cmd\":$(echo "$CMD" | head -c 120 | jq -Rs .)}"

ELAPSED=$(( ($(date +%s%N) / 1000000) - START_MS ))
log_hook "validate-bash" "allowed" "$ELAPSED" 2>/dev/null || true
exit 0
