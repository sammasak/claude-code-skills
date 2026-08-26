#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/fix.md"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must explain the double-installation root cause
if ! grep -qi "both\|duplicate\|twice\|collision\|programs.git.*package\|home.packages.*git\|two.*version" "$OUTPUT"; then
    echo "FAIL: must explain that git is being installed twice (via home.packages AND programs.git)"
    exit 1
fi

# Fix must remove git from home.packages (not remove programs.git)
if grep -q "pkgs.git" "$OUTPUT" && ! grep -qi "remove.*home.packages\|delete.*pkgs.git\|without.*pkgs.git" "$OUTPUT"; then
    # If they still have pkgs.git, the fix is wrong
    if grep -q "home.packages.*pkgs.git\|pkgs.git.*home.packages" "$OUTPUT"; then
        echo "FAIL: fix must remove pkgs.git from home.packages — programs.git already installs it"
        exit 1
    fi
fi

# Fix must keep programs.git enabled
if grep -q "programs.git" "$OUTPUT" && grep -qi "remove.*programs.git\|delete.*programs.git\|disable.*programs.git" "$OUTPUT"; then
    echo "FAIL: should NOT remove programs.git — it provides configuration; remove the raw package instead"
    exit 1
fi

# Must mention the general rule (programs modules manage their own package)
if ! grep -qi "programs.*module\|manage.*package\|already.*include\|don't.*add\|do not.*add\|remove.*home.packages" "$OUTPUT"; then
    echo "FAIL: must explain the general rule: programs.* modules install their own package — do not duplicate in home.packages"
    exit 1
fi

echo "PASS"
exit 0
