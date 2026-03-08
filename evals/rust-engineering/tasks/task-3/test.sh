#!/usr/bin/env bash
set -euo pipefail

OUTPUT="/tmp/eval-output/lints.toml"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must have workspace.lints.rust section
if ! grep -q "\[workspace.lints.rust\]" "$OUTPUT"; then
    echo "FAIL: must have [workspace.lints.rust] section"
    exit 1
fi

# Must forbid unsafe_code
if ! grep -q 'unsafe_code.*=.*"forbid"' "$OUTPUT"; then
    echo "FAIL: must set unsafe_code = \"forbid\""
    exit 1
fi

# Must have clippy all at warn with priority -1
if ! grep -qE 'all.*=.*\{.*level.*=.*"warn".*priority.*=.*-1' "$OUTPUT" && \
   ! grep -qE 'all.*warn' "$OUTPUT"; then
    echo "FAIL: must enable clippy::all at warn level"
    exit 1
fi

# Must have pedantic at warn
if ! grep -q "pedantic" "$OUTPUT"; then
    echo "FAIL: must enable pedantic lints"
    exit 1
fi

# Must NOT enable entire nursery group
if grep -q '"nursery".*=.*\{' "$OUTPUT" && ! grep -q "nursery.*warn\|nursery.*deny" "$OUTPUT"; then
    : # nursery mentioned but not as a group enable — OK
elif grep -qE 'nursery\s*=\s*\{[^}]*level[^}]*=.*"warn"' "$OUTPUT"; then
    echo "FAIL: must NOT enable entire nursery group"
    exit 1
fi

# Must have member crate opt-in
if ! grep -q "workspace = true" "$OUTPUT"; then
    echo "FAIL: must include member crate [lints] workspace = true opt-in"
    exit 1
fi

echo "PASS"
exit 0
