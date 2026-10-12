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
CWD=$(hook_cwd)

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
# Filesystem ops have NO deeper layer, and none is pending: the permission
# layer is blanket-allow with prefix-only denies (a recorded trade), so
# the fs residual is UNOWNED and accepted, not deferred. The residual:
# variable and ${IFS}-expanded targets, interpreter payloads (python -c
# shutil.rmtree), file indirection (Write a script, then bash script.sh —
# the hook sees only the command string), and destructive tools outside
# the named set (rm, dd, tee/cp, mkfs-family, partitioners, rsync
# --delete, find -delete). The coverage SPECIFICATION is the blocked set
# in tests/test-hooks.sh — a spelling without a test case there is
# residual by definition, never implied coverage.
SQ="'"
PFX='(^|[|&;`]|\$\()[[:space:]]*(\\?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|command|sudo|nice|eval|nohup|setsid|xargs|stdbuf|ionice|timeout|busybox|bash|sh|zsh|fish|-[^[:space:]]+|[0-9]+[smhd]?)[[:space:]]+)*\\?'
GP="${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|git)([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|-c[[:space:]]+[^[:space:]]+))*[[:space:]]+push"
KD="${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|kubectl)[^|&;]*[[:space:]]delete[[:space:]]([^|&;]*[[:space:]])?([a-z,-]+,)?(pvc|persistentvolumeclaims?|persistentvolumes?|pv|namespaces?|ns|kustomizations?|ks|helmreleases?|hr)([[:space:],/.]|\$)"

# Backslash-newline continuations are joined first (a command split across
# lines is one command), then escaped quotes are removed so nested shell -c
# payloads cannot hide a quote boundary from the unwrapper.
SCAN=$(echo "$CMD" | sed -z 's/\\\n/ /g' | sed 's/\\["'"${SQ}"']//g')
for _ in 1 2 3; do
  BEFORE=$(echo "$SCAN" | wc -l)
  PAYLOADS=$( { echo "$SCAN" | grep -oE "${PFX}(bash|sh|zsh|fish)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-c[[:space:]]+(${SQ}[^${SQ}]*${SQ}|\"[^\"]*\")" 2>/dev/null \
    | sed -E "s/^.*-c[[:space:]]+[${SQ}\"]//; s/[${SQ}\"]\$//"; \
    echo "$SCAN" | grep -oE "${PFX}(bash|sh|zsh|fish)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-c[[:space:]]+[^|&;]+" 2>/dev/null \
    | sed -E 's/^.*-c[[:space:]]+//' | sed "s/[\"${SQ}]//g"; \
    echo "$SCAN" | grep -oE "${PFX}eval[[:space:]]+[^|&;]+" 2>/dev/null \
    | sed -E 's/^.*eval[[:space:]]+//' | sed "s/[\"${SQ}]//g"; \
    echo "$SCAN" | grep -oE '\$\([[:space:]]*(echo|printf)[[:space:]]+[^)]*\)' 2>/dev/null \
    | sed -E 's/^\$\([[:space:]]*(echo|printf)[[:space:]]+//; s/\)$//' \
    | sed "s/^[\"${SQ}]//; s/[\"${SQ}]\$//"; } | sort -u)
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
# A git invocation that disables the pre-push guard this hook delegates the
# hard cases to: --no-verify skips all hooks; -c/--config-env core.hooksPath or
# GIT_CONFIG_* repoint/null the hook dir; -c alias. hides `push --force` behind
# a name; `git config` writes the same keys persistently. Matched on a
# dequoted, case-folded view (git config keys are case-insensitive) with the
# override anchored to git's leading global-flag region, so a quoted mention in
# a commit message or an echo is not command-position and does not trip it.
GITSCAN=$(printf '%s' "$SCAN" | sed 's/\\\(.\)/\1/g' | sed "s/[\"${SQ}]//g" | tr 'A-Z' 'a-z')
GBYP="core\\.hookspath|alias\\."
if echo "$GITSCAN" | grep -qE "${GP}[^|&;]*[[:space:]]--no-verify([[:space:]]|\$)"; then
  block "git push --no-verify disables the pre-push guard and is not allowed."
fi
if echo "$GITSCAN" | grep -qE "${PFX}git([[:space:]]+(-[a-z][[:space:]]*[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+(-c[[:space:]]*[^[:space:]]*(${GBYP})|--config-env[= ][^[:space:]]*(${GBYP}))"; then
  block "overriding git hooks/aliases via -c/--config-env around a git command is not allowed."
fi
if echo "$GITSCAN" | grep -qE "(^|[|&;\`]|\\\$\\()[[:space:]]*git_config_(parameters=[^[:space:]]*(${GBYP})|key_[0-9]+=(${GBYP})|count=[0-9])"; then
  block "overriding git hooks/aliases via GIT_CONFIG_* env is not allowed."
fi
if echo "$GITSCAN" | grep -qE "${PFX}git[[:space:]]+config[[:space:]][^|&;]*(${GBYP})" \
  && ! echo "$GITSCAN" | grep -qE "${PFX}git[[:space:]]+config[[:space:]][^|&;]*(--get|--list|[[:space:]]-l([[:space:]]|\$))"; then
  block "persistently setting core.hooksPath/alias via git config is not allowed."
fi
if echo "$STRIPPED" | grep -qiE "$KD"; then
  block "destructive kubectl delete (pvc/namespace/Flux object) needs the human; see the stateful-volume safety policy."
fi
# `flux delete <kustomization|helmrelease|source>` prunes the same stateful
# objects via the flux-system SA, which Kyverno exempts — so the gate is here.
if echo "$STRIPPED" | grep -qiE "${PFX}flux[[:space:]]+delete[[:space:]]+(kustomization|helmrelease|source|ks|hr)"; then
  block "flux delete of a reconciled object can prune PVCs/namespaces; needs the human."
fi
if echo "$SCAN" | grep -qE '\|[[:space:]]*(ba|z|fi)?sh([[:space:]]|$)' \
  && echo "$SCAN" | grep -qE 'git[[:space:]]+push[^|&;]*(--force|[[:space:]]-f([[:space:]]|$)|[[:space:]][+][^[:space:]])'; then
  block "piping text containing a force push into a shell is not allowed."
fi
if echo "$STRIPPED" | grep -qE "sops[^|&;]*(-e|encrypt)[^|&;]*/tmp/"; then
  block "SOPS encrypt from /tmp is unsafe; write plaintext to the repo path, then sops -e --in-place."
fi

# Destructive filesystem tier. The scan is normalised first (see below), so
# quoting, $(which), transparent wrappers, redirects, $(…)/backtick wrapping,
# /./ and x/../ path noise, and //doubled slashes are not evasions. The
# accepted residual stays: a variable or otherwise non-literal target
# (rm -rf "$DIR", ${X}), interpreter payloads (python -c shutil.rmtree), and
# file indirection (Write a script, then bash it — the hook sees only the
# command string). No deeper layer owns files; the coverage SPECIFICATION is
# the blocked set in tests/test-hooks.sh — a spelling without a test case
# there is residual by definition, never implied coverage.
# Root/home target: bare slashes, root-level globs (incl. a first-segment
# glob with one tail segment, and dot-globs that take a home's dotfiles),
# ~ or ~user, $HOME braced or not, ../-escapes back to a root, and
# top-level system dirs down to one segment. Segments are slash-squeezed
# before matching so //home//lukas is /home/lukas.
FSROOT="(^|[[:space:]])(/+|/+[^/[:space:]]*[*?[{][^/[:space:]]*(/[]A-Za-z0-9._@*?[{}-]+)?|~[A-Za-z0-9._-]*(/\\.?\\*|/)?|\\\$\\{?HOME\\}?(/\\.?\\*|/)?|(\\.\\./)+(home|etc|nix|var|usr|boot|opt|srv|root)(/[]A-Za-z0-9._@*?[{}-]+)?/?|/+(home|etc|nix|var|usr|boot|opt|srv|root)(/[]A-Za-z0-9._@*?[{}-]+)?(/\\.?\\*|/)?)([[:space:]]|\$)"
# The fs tier scans a NORMALISED copy so a destructive command cannot hide
# behind shell cosmetics. In order: unquote backslash escapes (r\m, /ho\me);
# drop quote characters (so "rm"/'rm'/rm'' and "/home/luka"s are the bare token);
# resolve $(which <tool>) to the tool; rewrite command-substitution and subshell
# delimiters ($( ` ( { ) to ';' (a command-position char), and ) } > < to spaces
# (so a redirect or group-close terminates the target); strip transparent
# MULTI-token wrapper prefixes (the nix/devenv/direnv shells, long and short
# forms) FIRST, then single-token transparent prefixes (time/exec/env and the
# compound keywords then/do/else) to ';' so the inner command sits at command
# position; collapse '/./', 'x/../' and repeated slashes so /home/./lukas,
# /home/a/../lukas and //home//lukas read as /home/lukas. [ { ] are glob chars.
SCAN=$(printf '%s' "$SCAN" \
  | sed 's/\\\(.\)/\1/g' \
  | sed "s/[\"${SQ}]//g" \
  | sed -E 's/\$\(which[[:space:]]+([A-Za-z0-9_.-]+)[[:space:]]*\)/\1/g' \
  | sed 's/\$(/\x01/g' \
  | sed 's/`/;/g; s/(/;/g; s/)/ /g; s/</ /g; s/>/ /g' \
  | sed -E 's/(^|[;|&[:space:]])\{[[:space:]]/\1; /g' \
  | sed -E 's/[[:space:]]\}([[:space:]]|;|&|\||$)/ \1/g' \
  | sed 's/\x01/;/g' \
  | sed -E 's#(^|[;|&[:space:]])(nix[[:space:]]+(shell|develop)[^;|&]*(-c|--command|--run)|nix-shell[^;|&]*(--run|--command|-c)|devenv[[:space:]]+shell([[:space:]]+--)?|direnv[[:space:]]+exec[[:space:]]+[^[:space:]]+)[[:space:]]+#\1;#g' \
  | sed -E 's#(^|[;|&[:space:]])(time|exec|/usr/bin/env|/bin/env|then|do|else|elif)[[:space:]]+#\1;#g' \
  | sed ':a; s#/\./#/#g; ta' \
  | sed ':b; s#[A-Za-z0-9_@-][A-Za-z0-9._@-]*/\.\./##g; tb' | tr -s '/')
# A glob segment directly under a root/home (/home/u/?*, /etc/*, ~/.[!.]*,
# $HOME/{*,.*}) expands to that dir's contents — the same wipe as the literal
# root. The glob metachar must be in the segment IMMEDIATELY under the root, so
# a scoped /home/u/proj/*.log (glob deeper down) is untouched.
GLOBUNDERROOT="(^|[[:space:]])(/+(home/[^/[:space:]]+|home|etc|nix|var|usr|boot|opt|srv|root)|~[A-Za-z0-9._-]*|\\\$\\{?HOME\\}?)/[^/[:space:]]*[*?[{][^/[:space:]]*"
# Tools invoked by absolute path still sit at command position.
ABS="(/[A-Za-z0-9._/-]*/)?"
# No force-flag requirement: with non-tty stdin (an agent's reality) GNU rm
# deletes write-protected trees silently even without -f, so recursion
# against a root/home target is the whole signal.
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  flags=$(printf '%s' "$seg" | sed "s/${SQ}[^${SQ}]*${SQ}//g; s/\"[^\"]*\"//g")
  printf '%s' "$flags" | grep -qE -- '(^|[[:space:]])(-[A-Za-z]*[rR][A-Za-z]*|--recursive)([[:space:]]|$)' || continue
  if printf '%s' "$seg" | tr -s '/' | grep -qE "$FSROOT|$GLOBUNDERROOT"; then
    block "recursive rm of a filesystem root or whole home is not allowed."
  fi
done < <(echo "$SCAN" | grep -oE "${PFX}(\\\$[A-Za-z_][A-Za-z0-9_]*|${ABS}rm)[[:space:]]+[^|&;]*" 2>/dev/null)
# cwd is statically known (unlike $DIR): a recursive rm of a bare glob, a
# dotfile glob, or a parent/sibling escape (rm -rf *, .[!.]*, ../x, ./*) run
# FROM a root/home dir wipes or escapes it. Block when the session cwd is a
# root or home root and the command has no cd of its own.
if [ -n "$CWD" ] \
  && printf '%s' "$CWD" | tr -s '/' | grep -qE '^(/|/(home/[^/]+|home|etc|nix|var|usr|boot|opt|srv|root))/?$' \
  && ! echo "$SCAN" | grep -qE "${PFX}cd[[:space:]]"; then
  if echo "$SCAN" | grep -qE "${PFX}${ABS}rm[[:space:]][^|&;]*-[A-Za-z]*[rR][A-Za-z]*[^|&;]*[[:space:]](\\./)?(\\.?\\[?[!^]?\\.?\\]?\\*|\\.\\.?)([[:space:]/]|\$)"; then
    block "recursive rm of a bare glob or escape from a root/home working directory is not allowed."
  fi
fi
# cd into a root/home (terminated by space, ;, |, &, or EOL) followed by a
# glob/dotglob recursive rm is the same wipe spelled relatively.
CDROOT="${PFX}cd[[:space:]]+(/+|~[A-Za-z0-9._-]*|\\\$\\{?HOME\\}?|/+(home|etc|nix|var|usr|boot|opt|srv|root)(/[A-Za-z0-9._@-]+)?)/?([[:space:];|&]|\$)"
if echo "$SCAN" | tr -s '/' | grep -qE "$CDROOT" \
  && echo "$SCAN" | grep -qE "${PFX}${ABS}rm[[:space:]][^|&;]*-[A-Za-z]*[rR][A-Za-z]*[^|&;]*[[:space:]](\\./)?\\.?\\[?[!^]?\\.?\\]?\\*([[:space:]]|\$)"; then
  block "cd into a root/home followed by recursive rm of a glob is not allowed."
fi
if echo "$SCAN" | grep -qE '\|[[:space:]]*xargs[[:space:]]+[^|&;]*rm[[:space:]]+[^|&;]*-[A-Za-z]*[rR]' \
  && echo "$SCAN" | tr -s '/' | grep -qE "$FSROOT"; then
  block "piping filesystem roots into xargs rm is not allowed."
fi
# rsync --delete and find -delete/-exec rm with a root/home target are the
# same destruction through sibling tools.
if echo "$SCAN" | grep -oE "${PFX}${ABS}rsync[[:space:]][^|&;]*" 2>/dev/null \
  | grep -E -- '--del' | tr -s '/' | grep -qE "$FSROOT"; then
  block "rsync --delete targeting a filesystem root or whole home is not allowed."
fi
# A home ROOT (/home/<user>) counts for find — "not user subdirs" means
# /home/<user>/<dir>, never the whole home itself.
FINDROOT="(^|[[:space:]])(~[A-Za-z0-9._-]*|\\\$\\{?HOME\\}?|/+(home(/[A-Za-z0-9._@-]+)?/?|(etc|nix|var|usr|boot|opt|srv|root)/?)?)([[:space:]]|\$)"
if echo "$SCAN" | grep -oE "${PFX}${ABS}find[[:space:]][^|&;]*" 2>/dev/null \
  | grep -E -- '(-delete|-exec(dir)?[[:space:]][^|&;]*rm)' | tr -s '/' | grep -qE "$FINDROOT"; then
  block "find -delete sweeping a filesystem root is not allowed."
fi
# Block-device path, covering the stable aliases (/dev/disk/by-id, /dev/mapper)
# and the kernel names. /dev/null, /dev/stdout, /dev/zero etc. are NOT devices
# to protect — dd/tee/cp to them is routine, so only real block devices match.
DEV='/dev/(sd|hd|vd|nvme|mmcblk|dm-|loop|disk/|mapper/)'
# dd/tee/cp run on SCAN (not STRIPPED) so a fully-quoted "of=/dev/sda" argument
# cannot delete itself before matching. Mentions stay immune (command position).
if echo "$SCAN" | grep -qE "${PFX}${ABS}dd[[:space:]][^|&;]*of=${DEV}"; then
  block "dd writing to a block device is not allowed from an agent session."
fi
if echo "$SCAN" | grep -qE "${PFX}${ABS}(tee|cp)[[:space:]][^|&;]*${DEV}"; then
  block "writing onto a block device via tee/cp is not allowed."
fi
if echo "$STRIPPED" | grep -qE "${PFX}${ABS}(mkfs(\\.[A-Za-z0-9]+)?|mke2fs|mkdosfs|mkntfs|mkswap|wipefs|blkdiscard)([[:space:]]|\$)" \
  || echo "$SCAN" | grep -qE "${PFX}${ABS}nvme[[:space:]]+format[[:space:]]"; then
  block "filesystem creation / block-device wipe tools are not allowed from an agent session."
fi
if echo "$SCAN" | grep -qE "${PFX}${ABS}(shred|sgdisk|sfdisk|fdisk|parted|badblocks)[[:space:]][^|&;]*${DEV}"; then
  block "partitioning or wiping a block device is not allowed from an agent session."
fi
if echo "$SCAN" | grep -qiE "${PFX}${ABS}cryptsetup[[:space:]][^|&;]*(luksformat|reencrypt|lukserase|erase)"; then
  block "cryptsetup format/erase of a device is not allowed from an agent session."
fi
if echo "$STRIPPED" | grep -qE '(--force|[[:space:]]-f([[:space:]]|$)|[[:space:]][+][^[:space:]])[^|&;]*\|[[:space:]]*xargs[[:space:]]+[^|&;]*git[[:space:]]+push'; then
  block "piping force arguments into xargs git push is not allowed."
fi
if echo "$STRIPPED" | grep -qE ">[[:space:]]*${DEV}"; then
  block "redirecting output onto a block device is not allowed."
fi

log_hook "validate-bash" "allowed" "$(( ($(date +%s%N) / 1000000) - START_MS ))" 2>/dev/null || true
exit 0
