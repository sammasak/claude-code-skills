#!/usr/bin/env bash
# Hook test suite — exercises the real Claude Code hook contract:
# one JSON object on stdin; feedback via exit 2 (+stderr) or stdout JSON.
# Run: bash tests/test-hooks.sh   (also wired as the repo pre-push gate)

set -uo pipefail

# Tests exercise the WORKTREE hooks (../hooks), not the deployed nix store copy.
# "suite green" proves the store only together with the separate pin==HEAD==store
# byte-diff the deploy flow runs; this suite does not read the store.
HOOKS="$(cd "$(dirname "$0")/../hooks" && pwd)"
TMP=$(mktemp -d)
# State/loop files land under the SAME fallback the hooks use ($HOME/.cache),
# not /tmp — clean both so bare-env runs leave nothing behind.
STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}"
trap 'rm -rf "$TMP"; rm -f "$STATE_DIR"/claude-hook-state-hooktest-*.json "$STATE_DIR"/claude-loop-hooktest-*.log' EXIT

PASS=0
FAIL=0

# check <name> <want_exit> <stderr_pattern|-> <stdout_pattern|-> <hook> <stdin_json>
check() {
  local name="$1" want_exit="$2" err_pat="$3" out_pat="$4" hook="$5" json="$6"
  local out err code
  out=$(printf '%s' "$json" | "$HOOKS/$hook" 2>"$TMP/err"); code=$?
  err=$(cat "$TMP/err")
  local ok=1
  [ "$code" -eq "$want_exit" ] || ok=0
  if [ "$err_pat" != "-" ]; then echo "$err" | grep -q "$err_pat" || ok=0; fi
  if [ "$out_pat" != "-" ]; then echo "$out" | grep -q "$out_pat" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (exit=$code want=$want_exit; stderr='$err' stdout='$out')"
  fi
}

j() { printf '{"session_id":"hooktest-%s","tool_input":%s}' "$1" "$2"; }

# ── validate-bash (PreToolUse: minimal speed-bump — 4 guards) ──
# 1. force push
check "force push blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push --force origin main"}')"
check "short -f force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push -f origin main"}')"
check "plus-refspec force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push origin +main"}')"
check "git -C force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git -C /x push --force"}')"
check "force-with-lease allowed (ancestry guard owns it)" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push --force-with-lease origin main"}')"
check "plain push allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin main"}')"
check "branch suffix force not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin feature--force"}')"
check "force-push mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'git push --force' > note.txt"}')"
check "force-push in commit message allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git commit -m \"disallow git push -f in hooks\""}')"
check "compound push-then-rm-f allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin main && rm -f /tmp/x"}')"
# 2. recursive rm of root/home
check "rm -rf slash blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /"}')"
check "rm -rf root glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /*"}')"
check "rm -rf tilde blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~"}')"
check "rm -rf HOME blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf $HOME"}')"
check "rm -rf whole home blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -fr /home/lukas"}')"
check "rm -rf etc blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /etc"}')"
check "sudo rm -rf slash blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"sudo rm -rf /"}')"
check "rm -rf project dir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ./target"}')"
check "rm -rf deep path allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/tmp/build"}')"
check "rm -f non-recursive allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -f /tmp/x.lock"}')"
check "rm -rf quoted-var glob allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf \"$TMP\"/*"}')"
check "rm -rf quoted-var trailing-slash allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf \"$out\"/"}')"
check "rm mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'never rm -rf /' >> doc.md"}')"
# 3. destructive kubectl delete
check "kubectl delete pvc blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl -n herman delete pvc data-0"}')"
check "kubectl delete namespace blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete namespace staging"}')"
check "kubectl delete pv blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete pv data-volume-7"}')"
check "kubectl delete pod allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete pod crashed-xyz -n app"}')"
check "kubectl get pvc allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl get pvc -A"}')"
check "kubectl delete mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'kubectl delete pvc x' >> runbook.md"}')"
# 4. SOPS from /tmp
check "sops from /tmp blocked" 2 "BLOCKED: SOPS" - \
  validate-bash.sh "$(j b1 '{"command":"sops -e /tmp/secret.yaml"}')"
check "sops in repo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"sops -d apps/x/secret.yaml"}')"
check "sops --extract to /tmp allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"sops -d --extract '\''[\"k\"]'\'' x.yaml > /tmp/val"}')"
check "normal command allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"cargo test"}')"
check "empty input tolerated" 0 - - validate-bash.sh ""
check "garbage input tolerated" 0 - - validate-bash.sh "not json at all"

# ── validate-nix (PostToolUse: exit 2 feeds stderr to the model) ──
printf '{ foo = ; }' > "$TMP/broken.nix"
printf '{ foo = 1; }' > "$TMP/ok.nix"
if command -v nix-instantiate >/dev/null 2>&1; then
  check "broken nix reported" 2 "Nix parse failed" - \
    validate-nix.sh "$(j n1 "{\"file_path\":\"$TMP/broken.nix\"}")"
  check "valid nix silent" 0 - - \
    validate-nix.sh "$(j n1 "{\"file_path\":\"$TMP/ok.nix\"}")"
fi
check "non-nix skipped" 0 - - \
  validate-nix.sh "$(j n1 "{\"file_path\":\"$TMP/whatever.txt\"}")"

# ── validate-shell (PostToolUse) ──
if command -v shellcheck >/dev/null 2>&1; then
  printf '#!/usr/bin/env bash\nrm $(ls)\n' > "$TMP/warn.sh"
  printf '#!/usr/bin/env bash\nls -- "$1"\n' > "$TMP/clean.sh"
  check "shellcheck finding reported" 2 "shellcheck:" - \
    validate-shell.sh "$(j s1 "{\"file_path\":\"$TMP/warn.sh\"}")"
  check "clean script silent" 0 - - \
    validate-shell.sh "$(j s1 "{\"file_path\":\"$TMP/clean.sh\"}")"
fi
check "non-shell skipped" 0 - - \
  validate-shell.sh "$(j s1 "{\"file_path\":\"$TMP/ok.nix\"}")"

# validate-rust was removed: per-edit `cargo check` re-improvised heavy
# verification the pre-push rust:ci gate already owns (lean-code), and its
# 120s cold-build could stall a memory-constrained host. Rust verification
# now lives only at the owning layer.

# ── validate-manifest (PostToolUse) ──
if command -v yq >/dev/null 2>&1; then
  printf 'kind: Deployment\nspec: {}\n' > "$TMP/workload.yaml"
  printf 'a: 1\n' > "$TMP/plain.yaml"
  printf 'kind: Deployment\n# seccompProfile allowPrivilegeEscalation resources:\nspec: {}\n' > "$TMP/comments.yaml"
  cat > "$TMP/compliant.yaml" <<'YAML'
kind: Deployment
spec:
  template:
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          securityContext:
            allowPrivilegeEscalation: false
          resources:
            requests: { cpu: 10m, memory: 64Mi }
            limits: { memory: 128Mi }
YAML
  check "workload missing baseline reported" 2 "missing" - \
    validate-manifest.sh "$(j m1 "{\"file_path\":\"$TMP/workload.yaml\"}")"
  check "commented keys do not satisfy probes" 2 "missing" - \
    validate-manifest.sh "$(j m1 "{\"file_path\":\"$TMP/comments.yaml\"}")"
  check "compliant workload silent" 0 - - \
    validate-manifest.sh "$(j m1 "{\"file_path\":\"$TMP/compliant.yaml\"}")"
  check "plain yaml silent" 0 - - \
    validate-manifest.sh "$(j m1 "{\"file_path\":\"$TMP/plain.yaml\"}")"
fi
check "non-yaml skipped" 0 - - \
  validate-manifest.sh "$(j m1 "{\"file_path\":\"$TMP/ok.nix\"}")"

# ── check-loop (PreToolUse: JSON advisory at 5+, exit 2 block at 12+) ──
LOOP_JSON="$(j loop '{"command":"cargo test --all"}')"
for _ in 1 2 3 4; do printf '%s' "$LOOP_JSON" | "$HOOKS/check-loop.sh" >/dev/null 2>&1; done
check "5th repeat advisory JSON" 0 - "additionalContext" check-loop.sh "$LOOP_JSON"
for _ in 6 7 8 9 10 11; do printf '%s' "$LOOP_JSON" | "$HOOKS/check-loop.sh" >/dev/null 2>&1; done
check "12th repeat blocked" 2 "Loop detected" - check-loop.sh "$LOOP_JSON"
check "different command unaffected" 0 - - \
  check-loop.sh "$(j loop '{"command":"git status"}')"

# ── check-git-state (Stop: human-facing stdout, always exit 0) ──
check "stop report exits zero" 0 - - check-git-state.sh "$(j g1 'null')"

# ── eval-contamination guard (mechanical; prevents the round-27 failure) ──
# The solving runner injects each SKILL.md body as the solver's system prompt,
# so a grader-distinctive token from a task's test.sh appearing in a skill body
# is answer-injection. Fail loudly if any does.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$REPO_ROOT/evals" ]; then
  # Curated tripwire tokens: grader-distinctive identifiers from
  # evals/*/tasks/*/test.sh that a generic skill would never need to name, and
  # that are absent from the legitimate de-contaminated skills (so real infra
  # names like sops-age / cert-manager, documented legitimately, never trip).
  # Auto-derivation was tried and rejected — it floods on common words
  # (API/JSON/HTTP) and on k8s fields skills rightly use (seccompProfile).
  # REVIEW this list when a solving task's distinctive entities change.
  CONTAM=""
  for tok in jetstack WORKSTATION_NAMESPACE installCRDs driftDetection; do
    grep -rqwF "$tok" "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null && CONTAM="$CONTAM $tok"
  done
  if [ -n "$CONTAM" ]; then
    FAIL=$((FAIL + 1)); echo "FAIL: eval-answer token(s) in a SKILL.md body:$CONTAM"
  else
    PASS=$((PASS + 1))
  fi
fi

# ── session keying (jq derives the per-session path; skipped without it) ──
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$(j key '{"command":"true"}')" | "$HOOKS/check-loop.sh" >/dev/null 2>&1
  if [ -f "${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-loop-hooktest-key.log" ]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "FAIL: loop state not keyed by session_id"
  fi
fi

SKIPPED=0
MISSING=""
command -v jq >/dev/null 2>&1 || { SKIPPED=$((SKIPPED + 1)); MISSING="$MISSING jq"; }
command -v nix-instantiate >/dev/null 2>&1 || { SKIPPED=$((SKIPPED + 2)); MISSING="$MISSING nix-instantiate"; }
command -v shellcheck >/dev/null 2>&1 || { SKIPPED=$((SKIPPED + 2)); MISSING="$MISSING shellcheck"; }
command -v yq >/dev/null 2>&1 || { SKIPPED=$((SKIPPED + 4)); MISSING="$MISSING yq"; }
echo "---"
echo "passed=$PASS failed=$FAIL skipped=$SKIPPED"
if [ "$SKIPPED" -gt 0 ] && [ "${ALLOW_SKIP:-0}" != "1" ]; then echo "refusing a silently under-tested run — missing tools:$MISSING (set ALLOW_SKIP=1 to accept; the pre-push gate runs them via nix shell)" >&2; exit 1; fi
[ "$FAIL" -eq 0 ]
