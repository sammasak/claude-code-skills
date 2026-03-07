#!/usr/bin/env bash
# PreToolUse Bash hook — musl enforcer + danger blocker
# Reads the proposed bash command from CLAUDE_TOOL_INPUT (JSON).
# Exits with code 2 + stderr message to BLOCK the command.
# Exits with code 0 to allow the command.

CMD=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")

emit_event() {
  local json="$1"
  curl -sf -X POST "${CLAUDE_WORKER_API:-http://localhost:4200}/events" \
    -H "Content-Type: application/json" \
    -d "$json" \
    --max-time 1 -o /dev/null 2>/dev/null || true
}

if [ -z "$CMD" ]; then
  exit 0
fi

# Agent-specific rules: only enforce on claude-worker VMs
if [ -d "${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}" ]; then
  # Block: cargo build without musl target
  # Rust binaries must be statically linked for container compatibility.
  if echo "$CMD" | grep -qE "cargo build|cargo test" && ! echo "$CMD" | grep -qE "musl|x86_64-unknown-linux-musl"; then
    echo "BLOCKED: Rust binaries must use --target x86_64-unknown-linux-musl for container compatibility. Add the target flag." >&2
    exit 2
  fi

  # Block: buildah push without --authfile
  # The auth file is pre-configured — use it, don't call buildah login.
  if echo "$CMD" | grep -qE "buildah push" && ! echo "$CMD" | grep -q "authfile"; then
    echo "BLOCKED: buildah push requires --authfile /var/lib/claude-worker/.config/containers/auth.json" >&2
    exit 2
  fi
fi

# Universal rules: active everywhere
# Block: force push
if echo "$CMD" | grep -qE "git push.*(--force([^-]|$)|-f\b)"; then
  echo "BLOCKED: force push is not allowed." >&2
  exit 2
fi

# Block: SOPS encrypt from /tmp
if echo "$CMD" | grep -qE "sops.*-e.*/tmp/|sops.*encrypt.*/tmp/"; then
  echo "BLOCKED: Do not encrypt SOPS files from /tmp. Write plaintext to the correct repo path first, then sops -e --in-place." >&2
  exit 2
fi

emit_event "{\"type\":\"tool_start\",\"tool\":\"bash\",\"cmd\":$(echo "$CMD" | head -c 120 | jq -Rs .)}"
exit 0
