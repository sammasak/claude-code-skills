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
check "rm -rf slash blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /"}')"
check "rm -fr whole home blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -fr /home/lukas"}')"
check "rm -rf HOME var blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf $HOME"}')"
check "rm -rf quoted home blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf \"/home/lukas\""}')"
check "rm -rf tilde blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~"}')"
check "rm -rf etc after chain blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"cd /x && rm -rf /etc"}')"
check "rm -rf project dir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ./target"}')"
check "rm -rf deep path allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/tmp/build"}')"
check "rm non-recursive allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -f /tmp/x.lock"}')"
check "rm mention in echo allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo 'never rm -rf /' >> doc.md"}')"
check "rm -rf double slash blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf //"}')"
check "rm -rf root glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /e*"}')"
check "rm -rf tilde-user blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~lukas"}')"
check "rm continuation line blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm \\\n-rf /etc"}')"
check "quoted printf rm payload blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"$(printf \"rm -rf /etc\")"}')"
check "rm -rf tilde-user subdir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~lukas/tmp/build"}')"
check "rm -r home no force blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -r /home/lukas"}')"
check "rm -r slash no force blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -r /"}')"
check "rm doubled slashes blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf //home//lukas"}')"
check "rm first-segment glob tail blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /ho*/lukas"}')"
check "rm dotdot escape to home blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ../../../../home/lukas"}')"
check "rm home dot-glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/.*"}')"
check "rm HOME dot-glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf $HOME/.*"}')"
check "cd home glob rm blocked" 2 "BLOCKED: cd into a root" - \
  validate-bash.sh "$(j b1 '{"command":"cd /home/lukas && rm -rf ./*"}')"
check "xargs rm root pipe blocked" 2 "BLOCKED: piping filesystem roots" - \
  validate-bash.sh "$(j b1 '{"command":"echo / | xargs rm -rf"}')"
check "quoted eval rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"eval '\''rm -rf /'\''"}')"
check "busybox rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"busybox rm -rf /"}')"
check "command-substitution rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"$(rm -rf /home/lukas)"}')"
check "backtick rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"echo `rm -rf /home/lukas`"}')"
check "quoted-command rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"\"rm\" -rf /home/lukas"}')"
check "empty-quote rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm'\'''\'' -rf /home/lukas"}')"
check "quoted-fragment target rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /hom\"\"e/lukas"}')"
check "dotslash-noise path blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/./lukas"}')"
check "dotdot-collapse path blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/tmp/../../lukas"}')"
check "bracket-glob path blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lu[k]as"}')"
check "brace-glob path blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/{lukas}"}')"
check "redirect-terminated rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas>/dev/null"}')"
check "time-wrapped rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"time rm -rf /home/lukas"}')"
check "env-wrapped rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"/usr/bin/env rm -rf /home/lukas"}')"
check "nix-shell-wrapped rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"nix shell nixpkgs#coreutils -c rm -rf /home/lukas"}')"
check "devenv-shell-wrapped rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"devenv shell -- rm -rf /home/lukas"}')"
check "which-substitution rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"$(which rm) -rf /home/lukas"}')"
check "git push --no-verify blocked" 2 "BLOCKED: git push --no-verify" - \
  validate-bash.sh "$(j b1 '{"command":"git push --no-verify origin main"}')"
check "git -c hooksPath push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c core.hooksPath=/dev/null push origin main"}')"
check "git -c alias push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c alias.p=push p origin main"}')"
check "GIT_CONFIG_PARAMETERS push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"GIT_CONFIG_PARAMETERS='core.hooksPath=/dev/null' git push origin main"}')"
check "normal git -c commit allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git -c user.email=x@y.z commit -m msg"}')"
check "mkswap on device blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"mkswap /dev/sdb2"}')"
check "cryptsetup luksFormat blocked" 2 "BLOCKED: cryptsetup" - \
  validate-bash.sh "$(j b1 '{"command":"cryptsetup luksFormat /dev/sda"}')"
check "tee onto by-id device blocked" 2 "BLOCKED: writing onto" - \
  validate-bash.sh "$(j b1 '{"command":"tee /dev/disk/by-id/wwn-0x5 < img"}')"
check "kubectl delete CamelCase pvc blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete PersistentVolumeClaim data-0 -n app"}')"
check "rm bare glob from home cwd blocked" 2 "BLOCKED: recursive rm of a bare glob" - \
  validate-bash.sh "$(printf '{"session_id":"hooktest-cwd","cwd":"/home/lukas","tool_input":{"command":"rm -rf *"}}')"
check "rm bare glob from project cwd allowed" 0 - - \
  validate-bash.sh "$(printf '{"session_id":"hooktest-cwd2","cwd":"/home/lukas/proj","tool_input":{"command":"rm -rf *"}}')"
check "rm -r relative dir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -r ./build"}')"
check "rm -rf sibling dir allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ../build"}')"
check "xargs rm without roots allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git ls-files -o | xargs rm -f"}')"
check "rm -rf braced HOME blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ${HOME}"}')"
check "rm -rf question glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /?*"}')"
check "rm -rf charclass glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /[a-z]*"}')"
check "abs-path rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"/bin/rm -rf /etc"}')"
check "quote-concat sh payload blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"sh -c \"rm -rf \"/"}')"
check "rsync delete to root blocked" 2 "BLOCKED: rsync --delete" - \
  validate-bash.sh "$(j b1 '{"command":"rsync -a --delete /tmp/empty/ /"}')"
check "rsync without delete allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rsync -a src/ dest/"}')"
check "find root delete blocked" 2 "BLOCKED: find -delete" - \
  validate-bash.sh "$(j b1 '{"command":"find / -xdev -delete"}')"
check "find whole-home delete blocked" 2 "BLOCKED: find -delete" - \
  validate-bash.sh "$(j b1 '{"command":"find /home/lukas -delete"}')"
check "find project delete allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"find ./build -name *.o -delete"}')"
check "find home-subdir delete allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"find /home/lukas/proj/target -name *.tmp -delete"}')"
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
check "abs-path mkfs blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"/sbin/mkfs.ext4 /dev/sdb1"}')"
check "shred block device blocked" 2 "BLOCKED: shredding" - \
  validate-bash.sh "$(j b1 '{"command":"shred /dev/sda"}')"
check "shred plain file allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"shred -u ./secret.txt"}')"
check "sgdisk zap blocked" 2 "BLOCKED: partitioning" - \
  validate-bash.sh "$(j b1 '{"command":"sgdisk --zap-all /dev/sda"}')"
check "parted mklabel blocked" 2 "BLOCKED: partitioning" - \
  validate-bash.sh "$(j b1 '{"command":"parted /dev/sda mklabel gpt"}')"
check "xargs force push pipe blocked" 2 "BLOCKED: piping force arguments" - \
  validate-bash.sh "$(j b1 '{"command":"echo --force | xargs git push origin main"}')"
check "xargs branch cleanup allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git branch --merged | xargs git branch -d"}')"
check "dd to file allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"dd if=backup.img of=./restore.img"}')"
check "mkfs blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"mkfs.ext4 /dev/sdb1"}')"
check "redirect to block device blocked" 2 "BLOCKED: redirecting output" - \
  validate-bash.sh "$(j b1 '{"command":"cat img > /dev/sda"}')"
# ── round-29: git-guard-bypass tier ──
check "git -c lowercase hookspath blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c core.hookspath=/dev/null push origin main"}')"
check "git -c mixedcase hooksPath blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c Core.HooksPath=/dev/null push origin main"}')"
check "git -c quoted hooksPath blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c \"core.hooksPath=/dev/null\" push origin main"}')"
check "git -c quoted alias-with-space blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c '\''alias.p=push --force'\'' p origin main"}')"
check "git --config-env hooksPath blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git --config-env=core.hooksPath=VAR push origin main"}')"
check "GIT_CONFIG_PARAMETERS lowercase blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"GIT_CONFIG_PARAMETERS='\''core.hookspath=/dev/null'\'' git push"}')"
check "git config write hooksPath blocked" 2 "BLOCKED: persistently setting" - \
  validate-bash.sh "$(j b1 '{"command":"git config core.hooksPath /dev/null && git push origin main"}')"
check "git config write alias blocked" 2 "BLOCKED: persistently setting" - \
  validate-bash.sh "$(j b1 '{"command":"git config alias.p \"push --force\""}')"
check "git push --no-verify blocked (r29)" 2 "BLOCKED: git push --no-verify" - \
  validate-bash.sh "$(j b1 '{"command":"git push --no-verify origin main"}')"
check "git -c user.email commit allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git -c user.email=x@y.z commit -m msg"}')"
check "git config --get hooksPath allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git config --get core.hooksPath"}')"
check "commit message mentioning hooksPath allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git commit -m \"block git -c core.hooksPath push\""}')"
check "echo GIT_CONFIG_COUNT allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"echo GIT_CONFIG_COUNT=1"}')"
# ── round-29: fs wrapper / path / glob / subshell ──
check "direnv exec rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"direnv exec . rm -rf /home/lukas"}')"
check "nix shell --command rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"nix shell nixpkgs#coreutils --command rm -rf /home/lukas"}')"
check "devenv shell no-dashdash rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"devenv shell rm -rf /home/lukas"}')"
check "backslash-escaped rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"r\\m -rf /home/lukas"}')"
check "backslash-in-path rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /ho\\me/lukas"}')"
check "subshell rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"(rm -rf /home/lukas)"}')"
check "brace-group rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"{ rm -rf /home/lukas; }"}')"
check "if-then rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"if true; then rm -rf /home/lukas; fi"}')"
check "home dotfile glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/.[!.]*"}')"
check "home question-star glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/?*"}')"
check "home brace glob blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/{*,.*}"}')"
check "home scoped deep glob allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf /home/lukas/proj/*.log"}')"
check "cd root semicolon glob blocked" 2 "BLOCKED: cd into a root" - \
  validate-bash.sh "$(j b1 '{"command":"cd /home/lukas; rm -rf *"}')"
check "find HOME delete blocked" 2 "BLOCKED: find -delete" - \
  validate-bash.sh "$(j b1 '{"command":"find $HOME -delete"}')"
check "dd to dev null allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"dd if=/dev/zero of=/dev/null bs=1M count=100"}')"
check "mke2fs on device blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"mke2fs /dev/sdb1"}')"
check "nvme format blocked" 2 "BLOCKED: filesystem creation" - \
  validate-bash.sh "$(j b1 '{"command":"nvme format /dev/nvme0n1"}')"
check "cryptsetup luksErase blocked" 2 "BLOCKED: cryptsetup" - \
  validate-bash.sh "$(j b1 '{"command":"cryptsetup luksErase /dev/sda"}')"
check "kubectl delete kustomization blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete kustomization apps -n flux-system"}')"
check "flux delete kustomization blocked" 2 "BLOCKED: flux delete" - \
  validate-bash.sh "$(j b1 '{"command":"flux delete kustomization apps --silent"}')"
# ── round-30: git env forms, plumbing, abbreviations, flux/kubectl ──
check "env GIT_CONFIG_PARAMETERS push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"env GIT_CONFIG_PARAMETERS=core.hookspath=/dev/null git push"}')"
check "GIT_CONFIG_KEY split-env push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"GIT_CONFIG_VALUE_0=/dev/null GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_COUNT=1 git push"}')"
check "export then push blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"export GIT_CONFIG_PARAMETERS=core.hooksPath=/dev/null; git push origin main"}')"
check "git send-pack force blocked" 2 "BLOCKED: force push" - \
  validate-bash.sh "$(j b1 '{"command":"git send-pack --force origin main"}')"
check "no-verify abbreviation blocked" 2 "BLOCKED: git push --no-verify" - \
  validate-bash.sh "$(j b1 '{"command":"git push --no-veri origin main"}')"
check "remote.push plus-refspec config blocked" 2 "BLOCKED: overriding git hooks" - \
  validate-bash.sh "$(j b1 '{"command":"git -c remote.origin.push=+refs/heads/main:refs/heads/main push origin"}')"
check "flux global-flag delete blocked" 2 "BLOCKED: flux delete" - \
  validate-bash.sh "$(j b1 '{"command":"flux -n flux-system delete kustomization apps"}')"
check "kubectl delete clusterpolicy blocked" 2 "BLOCKED: destructive kubectl" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl delete clusterpolicy deny-destructive-deletes"}')"
check "kubectl impersonation delete blocked" 2 "BLOCKED: kubectl --as" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl --as=system:serviceaccount:flux-system:kustomize-controller delete -f pvc.yaml"}')"
check "dollar-single-quote rm blocked" 2 "BLOCKED: recursive rm" - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf $'\''/home/lukas'\''"}')"
check "home glob-then-literal allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"rm -rf ~/proj/*/target"}')"
check "fdisk -l read allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"fdisk -l /dev/sda"}')"
check "parted print read allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"parted /dev/sda print"}')"
check "cp from device allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"cp /dev/sda /tmp/img"}')"
check "cp to device blocked" 2 "BLOCKED: copying onto" - \
  validate-bash.sh "$(j b1 '{"command":"cp /tmp/img /dev/sda"}')"
check "parted mkpart blocked" 2 "BLOCKED: partitioning" - \
  validate-bash.sh "$(j b1 '{"command":"parted /dev/sda mkpart primary 0% 100%"}')"
# ── round-31: segment-scoped git config, --no-verbose, auth can-i --as ──
check "git config read then write hooksPath blocked" 2 "BLOCKED: persistently setting" - \
  validate-bash.sh "$(j b1 '{"command":"git config --get user.name; git config core.hooksPath /dev/null"}')"
check "git config get-regexp then alias write blocked" 2 "BLOCKED: persistently setting" - \
  validate-bash.sh "$(j b1 '{"command":"git config --get-regexp alias; git config alias.p \"push --force\"; git p"}')"
check "git config --get only allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git config --get core.hooksPath"}')"
check "git push --no-verbose allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git push --no-verbose origin main"}')"
check "kubectl auth can-i --as allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl auth can-i --list --as=system:serviceaccount:app:sa"}')"
check "can-i then impersonate-delete blocked" 2 "BLOCKED: kubectl --as" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl auth can-i --list --as=foo && kubectl --as=foo delete -f x.yaml"}')"
# ── round-33: git -C config, break-glass annotate, find ~/, read-only FPs ──
check "git -C config hooksPath blocked" 2 "BLOCKED: persistently setting" - \
  validate-bash.sh "$(j b1 '{"command":"git -C /home/x/repo config --local core.hooksPath /dev/null"}')"
check "git config get subcommand allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git config get core.hooksPath"}')"
check "kubectl annotate allow-delete blocked" 2 "BLOCKED: setting the sammasak" - \
  validate-bash.sh "$(j b1 '{"command":"kubectl annotate pvc data-0 sammasak.dev/allow-delete=true"}')"
check "kubectl auth can-i delete pvc allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"kubectl auth can-i delete pvc -n app"}')"
check "find tilde-slash delete blocked" 2 "BLOCKED: find -delete" - \
  validate-bash.sh "$(j b1 '{"command":"find ~/ -delete"}')"
check "git -C normal config allowed" 0 - - \
  validate-bash.sh "$(j b1 '{"command":"git -C /home/x/repo config --local user.name Lukas"}')"
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
