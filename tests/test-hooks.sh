#!/usr/bin/env bash
# Unit tests for Claude Code hooks.
# Run: bash tests/test-hooks.sh
# Dependencies: jq, yq-go (auto-resolved via nix-shell if missing)

set -euo pipefail

# Ensure dependencies are in PATH
for dep in jq yq; do
  if ! command -v "$dep" &>/dev/null; then
    echo "Missing '$dep' — re-running under nix-shell..."
    exec nix-shell -p jq yq-go --run "bash $0 $*"
  fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
PASS=0
FAIL=0
TMPDIR_BASE=""

setup() {
  TMPDIR_BASE=$(mktemp -d)
  export CLAUDE_WORKER_HOME="$TMPDIR_BASE/worker"
}

teardown() {
  rm -rf "$TMPDIR_BASE"
  unset CLAUDE_WORKER_HOME CLAUDE_TOOL_INPUT
}

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — expected exit $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  local name="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — expected output to contain '$expected', got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_empty() {
  local name="$1" actual="$2"
  if [ -z "$actual" ]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — expected no output, got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ── check-goals.sh ────────────────────────────────────────────────────

test_check_goals_no_file() {
  setup
  # No goals.json exists → silent exit
  local out exit_code=0
  out=$("$HOOKS_DIR/check-goals.sh" 2>&1) || exit_code=$?
  assert_exit "check-goals: no file → exit 0" 0 "$exit_code"
  assert_output_empty "check-goals: no file → no output" "$out"
  teardown
}

test_check_goals_empty_array() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  echo '[]' > "$CLAUDE_WORKER_HOME/goals.json"
  local out exit_code=0
  out=$("$HOOKS_DIR/check-goals.sh" 2>&1) || exit_code=$?
  assert_exit "check-goals: empty array → exit 0" 0 "$exit_code"
  assert_output_empty "check-goals: empty array → no output" "$out"
  teardown
}

test_check_goals_all_done() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  # Goals with status "done" but no reviewed_at trigger Phase 3 (review block)
  cat > "$CLAUDE_WORKER_HOME/goals.json" << 'JSON'
[{"id":"a","goal":"task a","status":"done"},{"id":"b","goal":"task b","status":"done"}]
JSON
  local out exit_code=0
  out=$("$HOOKS_DIR/check-goals.sh" 2>&1) || exit_code=$?
  assert_exit "check-goals: all done (unreviewed) → exit 0" 0 "$exit_code"
  assert_output_contains "check-goals: all done → block for review" '"decision": "block"' "$out"
  assert_output_contains "check-goals: all done → review reason" 'completed goal' "$out"
  teardown
}

test_check_goals_one_pending() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  cat > "$CLAUDE_WORKER_HOME/goals.json" << 'JSON'
[{"id":"abc123","goal":"deploy the app","status":"pending"}]
JSON
  local out exit_code=0
  out=$("$HOOKS_DIR/check-goals.sh" 2>&1) || exit_code=$?
  assert_exit "check-goals: 1 pending → exit 0" 0 "$exit_code"
  assert_output_contains "check-goals: 1 pending → JSON block" '"decision": "block"' "$out"
  assert_output_contains "check-goals: 1 pending → includes id" "id=abc123" "$out"
  assert_output_contains "check-goals: 1 pending → includes goal" "deploy the app" "$out"
  teardown
}

test_check_goals_mixed() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  cat > "$CLAUDE_WORKER_HOME/goals.json" << 'JSON'
[
  {"id":"a","goal":"done task","status":"done"},
  {"id":"b","goal":"next task","status":"pending"},
  {"id":"c","goal":"later task","status":"pending"}
]
JSON
  local out exit_code=0
  out=$("$HOOKS_DIR/check-goals.sh" 2>&1) || exit_code=$?
  assert_exit "check-goals: mixed → exit 0" 0 "$exit_code"
  assert_output_contains "check-goals: mixed → JSON block" '"decision": "block"' "$out"
  assert_output_contains "check-goals: mixed → picks first pending" "id=b" "$out"
  assert_output_contains "check-goals: mixed → skips done goals" "next task" "$out"
  teardown
}

# ── validate-bash.sh ──────────────────────────────────────────────────

run_validate_bash() {
  local cmd="$1" exit_code=0
  export CLAUDE_TOOL_INPUT="{\"command\":\"$cmd\"}"
  local out
  out=$("$HOOKS_DIR/validate-bash.sh" 2>&1) || exit_code=$?
  echo "$exit_code|$out"
}

test_validate_bash_empty_input() {
  setup
  export CLAUDE_TOOL_INPUT='{}'
  local exit_code=0
  "$HOOKS_DIR/validate-bash.sh" > /dev/null 2>&1 || exit_code=$?
  assert_exit "validate-bash: empty input → exit 0" 0 "$exit_code"
  teardown
}

test_validate_bash_normal_command() {
  setup
  local result
  result=$(run_validate_bash "ls -la")
  assert_exit "validate-bash: ls -la → exit 0" 0 "${result%%|*}"
  teardown
}

test_validate_bash_force_push_long() {
  setup
  local result
  result=$(run_validate_bash "git push --force origin main")
  assert_exit "validate-bash: git push --force → exit 2" 2 "${result%%|*}"
  assert_output_contains "validate-bash: git push --force → BLOCKED" "BLOCKED" "${result#*|}"
  teardown
}

test_validate_bash_force_push_short() {
  setup
  local result
  result=$(run_validate_bash "git push -f origin main")
  assert_exit "validate-bash: git push -f → exit 2" 2 "${result%%|*}"
  teardown
}

test_validate_bash_normal_push_allowed() {
  setup
  local result
  result=$(run_validate_bash "git push origin main")
  assert_exit "validate-bash: git push (no force) → exit 0" 0 "${result%%|*}"
  teardown
}

test_validate_bash_sops_from_tmp() {
  setup
  local result
  result=$(run_validate_bash "sops -e /tmp/secret.yaml")
  assert_exit "validate-bash: sops -e /tmp → exit 2" 2 "${result%%|*}"
  assert_output_contains "validate-bash: sops /tmp → BLOCKED" "BLOCKED" "${result#*|}"
  teardown
}

test_validate_bash_sops_in_repo() {
  setup
  local result
  result=$(run_validate_bash "sops -e --in-place secrets/foo.yaml")
  assert_exit "validate-bash: sops in repo → exit 0" 0 "${result%%|*}"
  teardown
}

# VM-guarded rules (only active when CLAUDE_WORKER_HOME dir exists)

test_validate_bash_cargo_no_musl_on_vm() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  local result
  result=$(run_validate_bash "cargo build --release")
  assert_exit "validate-bash: cargo build without musl (VM) → exit 2" 2 "${result%%|*}"
  assert_output_contains "validate-bash: cargo build (VM) → musl message" "musl" "${result#*|}"
  teardown
}

test_validate_bash_cargo_with_musl_on_vm() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  local result
  result=$(run_validate_bash "cargo build --target x86_64-unknown-linux-musl --release")
  assert_exit "validate-bash: cargo build with musl (VM) → exit 0" 0 "${result%%|*}"
  teardown
}

test_validate_bash_cargo_no_musl_not_vm() {
  setup
  # CLAUDE_WORKER_HOME dir does NOT exist → VM guard skipped
  local result
  result=$(run_validate_bash "cargo build --release")
  assert_exit "validate-bash: cargo build without musl (laptop) → exit 0" 0 "${result%%|*}"
  teardown
}

test_validate_bash_buildah_no_authfile_on_vm() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  local result
  result=$(run_validate_bash "buildah push localhost/myimage:latest docker://registry.example.com/myimage:latest")
  assert_exit "validate-bash: buildah push without authfile (VM) → exit 2" 2 "${result%%|*}"
  assert_output_contains "validate-bash: buildah push (VM) → authfile message" "authfile" "${result#*|}"
  teardown
}

test_validate_bash_buildah_with_authfile_on_vm() {
  setup
  mkdir -p "$CLAUDE_WORKER_HOME"
  local result
  result=$(run_validate_bash "buildah push --authfile /var/lib/claude-worker/.config/containers/auth.json localhost/myimage:latest")
  assert_exit "validate-bash: buildah push with authfile (VM) → exit 0" 0 "${result%%|*}"
  teardown
}

test_validate_bash_buildah_not_vm() {
  setup
  local result
  result=$(run_validate_bash "buildah push localhost/myimage:latest")
  assert_exit "validate-bash: buildah push (laptop) → exit 0" 0 "${result%%|*}"
  teardown
}

# ── validate-manifest.sh ──────────────────────────────────────────────

test_validate_manifest_non_yaml() {
  setup
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/foo.txt"}'
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: .txt file → exit 0" 0 "$exit_code"
  assert_output_empty "validate-manifest: .txt → no output" "$out"
  teardown
}

test_validate_manifest_missing_file() {
  setup
  export CLAUDE_TOOL_INPUT='{"file_path":"/tmp/nonexistent.yaml"}'
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: missing file → exit 0" 0 "$exit_code"
  assert_output_empty "validate-manifest: missing → no output" "$out"
  teardown
}

test_validate_manifest_valid_yaml() {
  setup
  local f="$TMPDIR_BASE/valid.yaml"
  echo "key: value" > "$f"
  export CLAUDE_TOOL_INPUT="{\"file_path\":\"$f\"}"
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: valid YAML → exit 0" 0 "$exit_code"
  assert_output_contains "validate-manifest: valid YAML → checkmark" "YAML valid" "$out"
  teardown
}

test_validate_manifest_invalid_yaml() {
  setup
  local f="$TMPDIR_BASE/bad.yaml"
  printf "key: value\n  bad indent: here\n" > "$f"
  export CLAUDE_TOOL_INPUT="{\"file_path\":\"$f\"}"
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: invalid YAML → exit 0" 0 "$exit_code"
  assert_output_contains "validate-manifest: invalid YAML → WARNING" "WARNING" "$out"
  teardown
}

test_validate_manifest_deployment_missing_security() {
  setup
  local f="$TMPDIR_BASE/deploy.yaml"
  cat > "$f" << 'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx
YAML
  export CLAUDE_TOOL_INPUT="{\"file_path\":\"$f\"}"
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: deployment missing security → exit 0" 0 "$exit_code"
  assert_output_contains "validate-manifest: missing seccompProfile" "seccompProfile" "$out"
  assert_output_contains "validate-manifest: missing allowPrivilegeEscalation" "allowPrivilegeEscalation" "$out"
  assert_output_contains "validate-manifest: missing resources" "resource requests/limits" "$out"
  teardown
}

test_validate_manifest_deployment_with_security() {
  setup
  local f="$TMPDIR_BASE/secure-deploy.yaml"
  cat > "$f" << 'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
      securityContext:
        seccompProfile:
          type: RuntimeDefault
YAML
  export CLAUDE_TOOL_INPUT="{\"file_path\":\"$f\"}"
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: secure deployment → exit 0" 0 "$exit_code"
  assert_output_contains "validate-manifest: secure deployment → valid" "YAML valid" "$out"
  # Should NOT contain any warnings
  if echo "$out" | grep -q "WARNING"; then
    echo "FAIL: validate-manifest: secure deployment — unexpected WARNING in output: $out"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
  teardown
}

test_validate_manifest_yml_extension() {
  setup
  local f="$TMPDIR_BASE/config.yml"
  echo "key: value" > "$f"
  export CLAUDE_TOOL_INPUT="{\"file_path\":\"$f\"}"
  local out exit_code=0
  out=$("$HOOKS_DIR/validate-manifest.sh" 2>&1) || exit_code=$?
  assert_exit "validate-manifest: .yml extension → exit 0" 0 "$exit_code"
  assert_output_contains "validate-manifest: .yml → validates" "YAML valid" "$out"
  teardown
}

# ── Run all tests ─────────────────────────────────────────────────────

echo "Running hook unit tests..."
echo ""

# check-goals.sh
test_check_goals_no_file
test_check_goals_empty_array
test_check_goals_all_done
test_check_goals_one_pending
test_check_goals_mixed

# validate-bash.sh
test_validate_bash_empty_input
test_validate_bash_normal_command
test_validate_bash_force_push_long
test_validate_bash_force_push_short
test_validate_bash_normal_push_allowed
test_validate_bash_sops_from_tmp
test_validate_bash_sops_in_repo
test_validate_bash_cargo_no_musl_on_vm
test_validate_bash_cargo_with_musl_on_vm
test_validate_bash_cargo_no_musl_not_vm
test_validate_bash_buildah_no_authfile_on_vm
test_validate_bash_buildah_with_authfile_on_vm
test_validate_bash_buildah_not_vm

# validate-manifest.sh
test_validate_manifest_non_yaml
test_validate_manifest_missing_file
test_validate_manifest_valid_yaml
test_validate_manifest_invalid_yaml
test_validate_manifest_deployment_missing_security
test_validate_manifest_deployment_with_security
test_validate_manifest_yml_extension

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
