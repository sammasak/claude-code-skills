#!/usr/bin/env bash
# PreToolUse Bash hook — fast-feedback speed bump for the four COMMON dangerous
# mistakes, NOT a security boundary. It deliberately does NOT chase exotic
# spellings, wrappers, block-device tools, remote exec, or impersonation; the
# real boundaries own all of that:
#   - git history: the pre-push ancestry guard fires inside git and refuses
#     every force / non-fast-forward / branch-deletion spelling regardless of
#     how the push is written here, so this check is just early feedback.
#   - cluster state: the fail-closed Kyverno policy denies PVC/PV/Namespace
#     (and the pruning Flux kinds) deletion; the operator is deliberately
#     cluster-admin, so impersonation / policy deletion are an accepted trade.
#   - everything else is UNOWNED by this hook, by design.
# Simplified 2026-10-12 from a 334-line spelling-matcher back to this: the arms
# race against adversarial spellings was itself slop. Quoted content is stripped
# first so a MENTION (echo, commit message, grep pattern) is never blocked.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
START_MS=$(($(date +%s%N) / 1000000))

CMD=$(hook_command)
[ -z "$CMD" ] && exit 0

block() {
  echo "BLOCKED: $1" >&2
  log_hook "validate-bash" "blocked" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
  exit 2
}

SQ="'"
S=$(echo "$CMD" | sed -z "s/${SQ}[^${SQ}]*${SQ}//g; s/\"[^\"]*\"//g")

# 1. git force-push (common spelling only; the pre-push ancestry guard is the
#    real backstop and catches every other spelling).
if echo "$S" | grep -qE "git[[:space:]]+([^|&;]+[[:space:]]+)?push([[:space:]][^|&;]*)?([[:space:]]--force([^-]|\$)|[[:space:]]-[A-Za-z]*f[A-Za-z]*([[:space:]]|\$)|[[:space:]][+][^[:space:]])"; then
  block "force push is not allowed; revert with a new commit or push a branch (the pre-push guard enforces this regardless of spelling)."
fi

# 2. recursive rm of a filesystem root or whole home — the catastrophic accident.
if echo "$S" | grep -qE "(^|[|&;[:space:]])(sudo[[:space:]]+)?rm[[:space:]]+[^|&;]*-[A-Za-z]*r[A-Za-z]*[^|&;]*[[:space:]](/|/\*|~|\\\$HOME|/home/[A-Za-z0-9._-]+|/(etc|nix|var|usr|boot|opt|srv|root))(/\*?)?([[:space:]]|\$)"; then
  block "recursive rm of a filesystem root or whole home is not allowed."
fi

# 3. destructive kubectl delete of a stateful kind (Kyverno also denies these).
if echo "$S" | grep -qiE "kubectl[[:space:]]+([^|&;]+[[:space:]]+)?delete[[:space:]]+([^|&;]*[[:space:]])?(pvc|persistentvolumeclaims?|persistentvolumes?|pv|namespaces?|ns)([[:space:]]|\$)"; then
  block "destructive kubectl delete (pvc/pv/namespace) needs the human; Kyverno also denies it."
fi

# 4. SOPS encrypt from /tmp loses the repo's recipient set.
if echo "$S" | grep -qE "sops[^|&;]*(-e|encrypt)[^|&;]*/tmp/"; then
  block "SOPS encrypt from /tmp is unsafe; write to the repo path, then sops -e --in-place."
fi

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
