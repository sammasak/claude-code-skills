#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/fix.md"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must explain the renamed package or nixpkgs version issue
if ! grep -qi "renamed\|nixos-24\|package.*missing\|attribute.*missing\|version.*nixpkgs\|nixpkgs.*version" "$OUTPUT"; then
    echo "FAIL: must explain why the package attribute is missing (package renamed in newer nixpkgs)"
    exit 1
fi

# Must include nix flake update command
if ! grep -q "nix flake update\|flake update" "$OUTPUT"; then
    echo "FAIL: must include 'nix flake update' command to update nixpkgs input"
    exit 1
fi

# Must mention --update-input nixpkgs OR nix flake update nixpkgs to update only nixpkgs
if ! grep -qE "update-input.*nixpkgs|nix flake update nixpkgs|update nixpkgs" "$OUTPUT"; then
    echo "FAIL: must show how to update ONLY the nixpkgs input (not all inputs)"
    exit 1
fi

# Must mention --dry-run or nixos-rebuild test as safe approach
if ! grep -qiE "dry.run|nixos-rebuild test|boot.*before.*switch" "$OUTPUT"; then
    echo "FAIL: must explain safe testing before switching (--dry-run or nixos-rebuild test)"
    exit 1
fi

echo "PASS"
exit 0
