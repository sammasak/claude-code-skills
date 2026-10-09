#!/usr/bin/env bash
# PreToolUse Bash hook — danger blocker.
# Exit 2 + stderr BLOCKS the command and feeds the message back to Claude;
# exit 0 allows. --force-with-lease is deliberately not matched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
read_hook_input
init_state 2>/dev/null || true
START_MS=$(($(date +%s%N) / 1000000))

CMD=$(hook_command)
[ -z "$CMD" ] && exit 0

block() {
  echo "BLOCKED: $1" >&2
  log_hook "validate-bash" "blocked" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
  exit 2
}

# Structural matching, not substring matching. An invocation sits at command
# position, tolerating VAR= assignments, wrapper commands, an escaped \git,
# and git's global flags; shell -c payloads are unwrapped and rescanned so a
# wrapper cannot smuggle the invocation. Mentions stay immune: quoted CONTENT
# is stripped (multi-line aware, sed -z) before matching, and a real push
# that QUOTES a leading-dash argument is refused as flag smuggling. The same
# skeleton guards destructive kubectl deletes (stateful-volume safety).
# Statically unknowable spellings (eval "$X", git $SUB, kubectl delete -f,
# rm -rf "$DIR") are owned by the semantic layers where one exists: the
# pre-push ancestry guard and the fail-closed kyverno admission policy.
# Filesystem ops have NO deeper layer — the fs tier below covers literal
# spellings and the variable-target residual is accepted, not hidden.
SQ="'"
PFX='(^|[|&;`]|\$\()[[:space:]]*(\\?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|command|sudo|nice|eval|nohup|setsid|xargs|stdbuf|ionice|timeout|bash|sh|zsh|fish|-[^[:space:]]+|[0-9]+[smhd]?)[[:space:]]+)*\\?'
GP="${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|git)([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|-c[[:space:]]+[^[:space:]]+))*[[:space:]]+push"
KD="${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|kubectl)[^|&;]*[[:space:]]delete[[:space:]]([^|&;]*[[:space:]])?([a-z,-]+,)?(pvc|persistentvolumeclaims?|persistentvolumes?|pv|namespaces?|ns)([[:space:],/]|\$)"

# Escaped quotes are removed first so nested shell -c payloads cannot hide a
# quote boundary from the unwrapper.
SCAN=$(echo "$CMD" | sed 's/\\["'"${SQ}"']//g')
for _ in 1 2 3; do
  BEFORE=$(echo "$SCAN" | wc -l)
  PAYLOADS=$( { echo "$SCAN" | grep -oE "${PFX}(bash|sh|zsh|fish)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-c[[:space:]]+(${SQ}[^${SQ}]*${SQ}|\"[^\"]*\")" 2>/dev/null \
    | sed -E "s/^.*-c[[:space:]]+[${SQ}\"]//; s/[${SQ}\"]\$//"; \
    echo "$SCAN" | grep -oE '\$\([[:space:]]*(echo|printf)[[:space:]]+[^)]*\)' 2>/dev/null \
    | sed -E 's/^\$\([[:space:]]*(echo|printf)[[:space:]]+//; s/\)$//'; } | sort -u)
  [ -z "$PAYLOADS" ] && break
  SCAN=$(printf '%s\n%s' "$SCAN" "$PAYLOADS" | sort -u)
  [ "$(echo "$SCAN" | wc -l)" -eq "$BEFORE" ] && break
done
STRIPPED=$(echo "$SCAN" | sed -z "s/${SQ}[^${SQ}]*${SQ}//g; s/\"[^\"]*\"//g")

if echo "$STRIPPED" | grep -qE "${GP}[^|&;]*([[:space:]]--force([^-]|\$)|[[:space:]]-[A-Za-z]*f[A-Za-z]*([[:space:]]|\$)|[[:space:]][+][^[:space:]])"; then
  block "force push (including plus-refspec) is not allowed; revert with a new commit or push a branch."
fi
if echo "$SCAN" | grep -qE "${GP}[^|&;]*[\"${SQ}][[:space:]]*-"; then
  block "quoted flags to git push are not allowed."
fi
if echo "$STRIPPED" | grep -qE "$KD"; then
  block "destructive kubectl delete (pvc/namespace) needs the human; see the stateful-volume safety policy."
fi
if echo "$SCAN" | grep -qE '\|[[:space:]]*(ba|z|fi)?sh([[:space:]]|$)' \
  && echo "$SCAN" | grep -qE 'git[[:space:]]+push[^|&;]*(--force|[[:space:]]-f([[:space:]]|$)|[[:space:]][+][^[:space:]])'; then
  block "piping text containing a force push into a shell is not allowed."
fi
if echo "$STRIPPED" | grep -qE "sops[^|&;]*(-e|encrypt)[^|&;]*/tmp/"; then
  block "SOPS encrypt from /tmp is unsafe; write plaintext to the repo path, then sops -e --in-place."
fi

# Destructive filesystem tier. Literal spellings only: a variable target
# (rm -rf "$DIR") is statically unknowable and no deeper layer owns files —
# that residual risk is accepted and documented, not silently covered.
# Targets quoted at the call site are still matched (quotes allowed around
# the path token), so quoting is not an evasion.
FSROOT="(^|[[:space:]])[\"${SQ}]?(/|/\\*|~|~/\\*?|\\\$HOME/?\\*?|/(home|etc|nix|var|usr|boot|opt|srv|root)(/[A-Za-z0-9._@-]+)?/?\\*?)[\"${SQ}]?([[:space:]]|\$)"
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  flags=$(printf '%s' "$seg" | sed "s/${SQ}[^${SQ}]*${SQ}//g; s/\"[^\"]*\"//g")
  printf '%s' "$flags" | grep -qE -- '(^|[[:space:]])(-[A-Za-z]*[rR][A-Za-z]*|--recursive)([[:space:]]|$)' || continue
  printf '%s' "$flags" | grep -qE -- '(^|[[:space:]])(-[A-Za-z]*f[A-Za-z]*|--force)([[:space:]]|$)' || continue
  if printf '%s' "$seg" | grep -qE "$FSROOT"; then
    block "recursive force rm of a filesystem root or whole home is not allowed."
  fi
done < <(echo "$SCAN" | grep -oE "${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|rm)[[:space:]]+[^|&;]*" 2>/dev/null)
if echo "$STRIPPED" | grep -qE "${PFX}dd[[:space:]][^|&;]*of=[\"${SQ}]?/dev/"; then
  block "dd writing to a block device is not allowed from an agent session."
fi
if echo "$STRIPPED" | grep -qE "${PFX}(mkfs(\\.[A-Za-z0-9]+)?|wipefs|blkdiscard)([[:space:]]|\$)"; then
  block "filesystem creation / block-device wipe tools are not allowed from an agent session."
fi
if echo "$STRIPPED" | grep -qE '>[[:space:]]*/dev/(sd|hd|vd|nvme|mmcblk|dm-|loop)'; then
  block "redirecting output onto a block device is not allowed."
fi

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
