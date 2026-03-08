# Task: Write a flake.nix devShell for Rust development

## Context
You need a `flake.nix` for a Rust project that provides a reproducible development shell with:
- Rust toolchain (stable)
- `cargo`, `rustfmt`, `clippy`
- `just` task runner
- `buildah` and `skopeo` for container builds
- `kubectl` and `flux` CLI tools

The shell should follow the nix-flake-development skill patterns.

## Your Task
Write a complete, working `flake.nix` that provides this devShell.

## Deliverable
Write to `/tmp/eval-output/flake.nix`.
