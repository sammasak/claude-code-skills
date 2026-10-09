#!/usr/bin/env bash
# Hook test suite — exercises the real Claude Code hook contract:
# one JSON object on stdin; feedback via exit 2 (+stderr) or stdout JSON.
# Run: bash tests/test-hooks.sh   (also wired as the repo pre-push gate)

set -uo pipefail

HOOKS="$(cd "$(dirname "$0")/../hooks" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; rm -f "${XDG_RUNTIME_DIR:-/tmp}"/claude-hook-state-hooktest-*.json "${XDG_RUNTIME_DIR:-/tmp}"/claude-loop-hooktest-*.log' EXIT

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

# ── validate-bash (PreToolUse: exit 2 blocks) ──
check "force push blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push --force origin main"}')"
check "force-with-lease allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push --force-with-lease origin main"}')"
check "sops from /tmp blocked" 2 "BLOCKED: SOPS" - \
  validate-bash.sh "$(j b1 '{"command":"sops -e /tmp/secret.yaml"}')"
check "normal command allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"cargo test"}')"
check "short -f flag blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push -f origin main"}')"
check "compound rm -f not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin main && rm -f /tmp/x"}')"
check "quoted literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'git push --force' > note.txt"}')"
check "double-quoted literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo \"see git push --force docs\" >> README.md"}')"
check "commit message literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git commit -m \"disallow git push -f in hooks\""}')"
check "grep pattern literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"grep -rn \"git push -f\" docs/"}')"
check "branch suffix -f not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin wip-f"}')"
check "multiline quoted literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git status\ngrep 'git push --force' docs/a.md"}')"
check "multiline real force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"cd /tmp\ngit push --force origin main"}')"
check "quoted flag smuggling blocked" 2 "BLOCKED: quoted flags" - \
  validate-bash.sh "$(j b1 '{"command":"git push origin main \"--force\""}')"
check "quoted short flag smuggling blocked" 2 "BLOCKED: quoted flags" - \
  validate-bash.sh "$(j b1 '{"command":"git push '\''-f'\'' origin main"}')"
check "multiline commit message literal not misblocked" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git commit -m \"subject line\n\nnever git push --force here\n\""}')"
check "env-prefixed force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"env git push --force origin main"}')"
check "git -C force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git -C /home/x/repo push --force"}')"
check "var-assignment prefix force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"GIT_TRACE=1 git push -f origin main"}')"
check "backslash-escaped git force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"\\git push --force origin main"}')"
check "bash -c payload force blocked" 2 "BLOCKED" - \
  validate-bash.sh "$(j b1 '{"command":"bash -c \u0027git push --force origin main\u0027"}')"
check "plus-refspec force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push origin +main"}')"
check "flag-suffix branch name allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push origin feature--force"}')"
check "kubectl delete pvc blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl -n herman delete pvc data-0"}')"
check "kubectl delete namespace blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete namespace staging"}')"
check "kubectl delete pv blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete pv data-volume-7"}')"
check "backtick-wrapped delete pvc blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"echo `kubectl delete pvc data-0`"}')"
check "comma resource list blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete pvc,ns foo"}')"
check "var-indirect kubectl delete blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"K=kubectl; $K delete pvc data-0"}')"
check "var-indirect force push blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"GIT=git; $GIT push --force origin main"}')"
check "bundled short flag blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git push -fu origin main"}')"
check "echo-substitution payload blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"$(echo git push --force origin main)"}')"
check "kubectl delete persistentvolume blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl -n x delete persistentvolume pv-7"}')"
check "kubectl get pvc allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl get pvc -A"}')"
check "kubectl delete pod allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete pod crashed-xyz -n app"}')"
check "kubectl mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'kubectl delete pvc x' >> runbook.md"}')"
check "rm -rf slash blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /"}')"
check "rm -fr whole home blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -fr /home/lukas"}')"
check "rm -rf HOME var blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf $HOME"}')"
check "rm -rf quoted home blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf \"/home/lukas\""}')"
check "rm -rf tilde blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~"}')"
check "rm -rf etc after chain blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"cd /x && rm -rf /etc"}')"
check "rm -rf project dir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ./target"}')"
check "rm -rf deep path allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/tmp/build"}')"
check "rm non-recursive allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -f /tmp/x.lock"}')"
check "rm mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'never rm -rf /' >> doc.md"}')"
check "rm -rf double slash blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf //"}')"
check "rm -rf root glob blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /e*"}')"
check "rm -rf tilde-user blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~lukas"}')"
check "rm continuation line blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm \\\n-rf /etc"}')"
check "quoted printf rm payload blocked" 2 "BLOCKED: recursive force rm" - \
  validate-bash.sh "$(j b1 '{"command":"$(printf \"rm -rf /etc\")"}')"
check "rm -rf tilde-user subdir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~lukas/tmp/build"}')"
check "dd onto block device blocked" 2 "BLOCKED: dd writing" - \
  validate-bash.sh "$(j b1 '{"command":"dd if=/dev/zero of=/dev/sda bs=1M"}')"
check "dd quoted of-target blocked" 2 "BLOCKED: dd writing" - \
  validate-bash.sh "$(j b1 '{"command":"dd if=/dev/zero \"of=/dev/sda\""}')"
check "tee onto block device blocked" 2 "BLOCKED: writing onto" - \
  validate-bash.sh "$(j b1 '{"command":"tee /dev/sda < img"}')"
check "tee to dev null allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo hi | tee /dev/null"}')"
check "wipefs blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"wipefs -a /dev/sda"}')"
check "blkdiscard blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"blkdiscard /dev/sdb"}')"
check "append onto block device blocked" 2 "BLOCKED: redirecting output" - \
  validate-bash.sh "$(j b1 '{"command":"cat img >> /dev/sdb"}')"
check "dd to file allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"dd if=backup.img of=./restore.img"}')"
check "mkfs blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"mkfs.ext4 /dev/sdb1"}')"
check "redirect to block device blocked" 2 "BLOCKED: redirecting output" - \
  validate-bash.sh "$(j b1 '{"command":"cat img > /dev/sda"}')"
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

# ── validate-rust (PostToolUse): skip paths only — full cargo is too heavy ──
check "non-rs skipped" 0 - - \
  validate-rust.sh "$(j r1 "{\"file_path\":\"$TMP/ok.nix\"}")"
printf 'fn main() {}' > "$TMP/stray.rs"
check "stray rs outside workspace skipped" 0 - - \
  validate-rust.sh "$(j r1 "{\"file_path\":\"$TMP/stray.rs\"}")"

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

# ── session keying (jq derives the per-session path; skipped without it) ──
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$(j key '{"command":"true"}')" | "$HOOKS/check-loop.sh" >/dev/null 2>&1
  if [ -f "${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-loop-hooktest-key.log" ]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "FAIL: loop state not keyed by session_id"
  fi
fi

SKIPPED=0
command -v jq >/dev/null 2>&1 || SKIPPED=$((SKIPPED + 1))
command -v nix-instantiate >/dev/null 2>&1 || SKIPPED=$((SKIPPED + 2))
command -v shellcheck >/dev/null 2>&1 || SKIPPED=$((SKIPPED + 2))
command -v yq >/dev/null 2>&1 || SKIPPED=$((SKIPPED + 4))
echo "---"
echo "passed=$PASS failed=$FAIL skipped=$SKIPPED"
if [ "$SKIPPED" -gt 0 ] && [ "${ALLOW_SKIP:-0}" != "1" ]; then echo "refusing a silently under-tested run (set ALLOW_SKIP=1 to accept)" >&2; exit 1; fi
[ "$FAIL" -eq 0 ]
