#!/usr/bin/env bash
# PreToolUse hook: automatic activity reporting
# Fires before Bash/Write/Edit/MultiEdit tool calls.
# Maps meaningful operations to human-readable progress messages.
# Exits 0 always — never blocks execution.

# Only active on claude-worker VMs
WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
[ -d "$WORKER_HOME" ] || exit 0

TOOL="${CLAUDE_TOOL_NAME:-}"
INPUT="${CLAUDE_TOOL_INPUT:-}"

# ── Deduplication: skip if we sent the same message within 30 seconds ──────
SAFE_SESSION="${CLAUDE_SESSION_ID:-$$}"
SAFE_SESSION="${SAFE_SESSION//\//_}"
DEDUP_FILE="/tmp/report-activity-last-${SAFE_SESSION}.txt"
emit_if_new() {
  local msg="$1"
  [ -z "$msg" ] && return
  local now
  now=$(date +%s)
  local last_msg="" last_time=0
  if [ -f "$DEDUP_FILE" ]; then
    last_msg=$(head -1 "$DEDUP_FILE" 2>/dev/null || echo "")
    last_time=$(tail -1 "$DEDUP_FILE" 2>/dev/null || echo "0")
  fi
  local elapsed=$(( now - last_time ))
  if [ "$last_msg" = "$msg" ] && [ "$elapsed" -lt 30 ]; then
    return  # Duplicate within 30s — skip
  fi
  printf '%s\n%s\n' "$msg" "$now" > "$DEDUP_FILE"
  curl -sf -X POST "${CLAUDE_WORKER_API:-http://localhost:4200}/events" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"progress\",\"message\":$(printf '%s' "$msg" | jq -Rs .)}" \
    --max-time 5 -o /dev/null 2>/dev/null || true
}

# ── Write / Edit tools: report file being written ──────────────────────────
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ] || [ "$TOOL" = "MultiEdit" ]; then
  FILE=$(printf '%s' "$INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")
  if [ -n "$FILE" ]; then
    # Show last 2 path components: src/lib/api.py → "routes/api.py"
    SHORT=$(printf '%s' "$FILE" | awk -F/ '{n=NF; if(n>=2) printf "%s/%s", $(n-1), $n; else print $n}' | sed 's|^/||')
    emit_if_new "Writing ${SHORT}…"
  fi
  exit 0
fi

# ── Bash tool: pattern-match the command ────────────────────────────────────
if [ "$TOOL" = "Bash" ]; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.command // ""' 2>/dev/null | head -1 | cut -c1-120)
  [ -z "$CMD" ] && exit 0

  # Dependency installation
  if printf '%s' "$CMD" | grep -qE 'pip install|uv install|uv sync|npm install|cargo fetch'; then
    emit_if_new "Installing dependencies…"

  # Compilation (cargo build — can be the longest step for Rust projects)
  elif printf '%s' "$CMD" | grep -qE 'cargo build'; then
    emit_if_new "Compiling…"

  # Tests
  elif printf '%s' "$CMD" | grep -qE 'cargo test|pytest'; then
    emit_if_new "Running tests…"

  # Container build (long — most important to signal early)
  elif printf '%s' "$CMD" | grep -qE 'buildah build|docker build'; then
    emit_if_new "Building your app…"

  # Container push
  elif printf '%s' "$CMD" | grep -qE 'buildah push|docker push|skopeo copy'; then
    emit_if_new "Uploading your app…"

  # Kubernetes deployment
  elif printf '%s' "$CMD" | grep -qE 'kubectl apply|flux reconcile|helm upgrade|helm install'; then
    emit_if_new "Deploying your app…"

  # Kubernetes status check (post-deploy verification)
  elif printf '%s' "$CMD" | grep -qE 'kubectl rollout status|kubectl wait'; then
    emit_if_new "Verifying deployment…"

  # Git push (source code save)
  elif printf '%s' "$CMD" | grep -qE 'git push'; then
    emit_if_new "Saving your code…"

  # Nix environment setup
  elif printf '%s' "$CMD" | grep -qE 'nix develop|nix run|nix build'; then
    emit_if_new "Setting up build environment…"

  # Dev server start (uvicorn, vite, node server)
  elif printf '%s' "$CMD" | grep -qE 'uvicorn|vite dev|node.*server|python.*-m.*http'; then
    emit_if_new "Starting preview server…"

  # Health check / curl test
  elif printf '%s' "$CMD" | grep -qE '^curl.*http(s)?://'; then
    emit_if_new "Testing your app…"

  # Everything else: do not report (too noisy)
  fi
fi

exit 0
