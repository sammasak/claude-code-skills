#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${EVAL_OUTPUT_DIR:-/tmp/eval-output}/flake.nix"
if [[ ! -f "$OUTPUT" ]]; then echo "FAIL: $OUTPUT not found"; exit 1; fi

# Must have basic flake structure
if ! grep -q "inputs\|outputs\|nixpkgs" "$OUTPUT"; then
    echo "FAIL: must have flake inputs with nixpkgs"
    exit 1
fi

# Must have devShell output
if ! grep -q "devShell\|devShells" "$OUTPUT"; then
    echo "FAIL: must provide devShell output"
    exit 1
fi

# Must include Rust tools
if ! grep -qE "rustup|rust-toolchain|rustc|cargo|fenix|rust-overlay" "$OUTPUT"; then
    echo "FAIL: must include Rust toolchain"
    exit 1
fi

# Must include just
if ! grep -q "just" "$OUTPUT"; then
    echo "FAIL: must include just task runner"
    exit 1
fi

# Must include buildah or container tools
if ! grep -q "buildah\|skopeo" "$OUTPUT"; then
    echo "FAIL: must include buildah and skopeo for container workflows"
    exit 1
fi

# Must include kubectl
if ! grep -q "kubectl" "$OUTPUT"; then
    echo "FAIL: must include kubectl"
    exit 1
fi

echo "PASS"
exit 0
