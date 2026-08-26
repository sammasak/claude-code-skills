#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/flake.nix"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must have both hosts
if ! grep -q "workstation" "$OUTPUT"; then
    echo "FAIL: must keep existing workstation host"
    exit 1
fi

if ! grep -q '"server"\|nixosConfigurations\.server' "$OUTPUT"; then
    echo "FAIL: must add server host"
    exit 1
fi

# Both hosts must reference common.nix
COMMON_COUNT=$(grep -c "common.nix\|common" "$OUTPUT" || true)
if [[ "$COMMON_COUNT" -lt 2 ]]; then
    echo "FAIL: common.nix must appear at least twice (once per host)"
    exit 1
fi

# Must use nixpkgs.lib.nixosSystem (not some other pattern)
if ! grep -q "nixosSystem\|nixpkgs.lib" "$OUTPUT"; then
    echo "FAIL: must use nixpkgs.lib.nixosSystem to define hosts"
    exit 1
fi

echo "PASS"
exit 0
