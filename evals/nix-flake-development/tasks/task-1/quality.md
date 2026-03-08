# Quality Rubric — Task 1 (flake.nix devShell for Rust)

Evaluate the generated flake.nix on:

1. **devShell output** (0-2): Is a proper devShell or devShells output defined?
   - 2: `devShells.default` or `devShell` output correctly defined with mkShell or equivalent
   - 1: devShell defined but not accessible as the default
   - 0: No devShell output

2. **Rust toolchain** (0-2): Is a Rust toolchain included?
   - 2: Rust toolchain via rustup overlay, fenix, or nixpkgs rust packages with cargo, rustfmt, clippy
   - 1: Only rustc/cargo included, missing rustfmt or clippy
   - 0: No Rust toolchain

3. **Additional tools** (0-2): Are the required non-Rust tools included?
   - 2: All of `just`, `buildah`, `skopeo`, `kubectl`, and `flux` present
   - 1: Most tools present (3-4 of 5)
   - 0: Few tools (fewer than 3)

4. **nixpkgs input** (0-2): Is the nixpkgs input properly declared?
   - 2: `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-..."` in the inputs block
   - 1: nixpkgs used but without explicit input declaration
   - 0: No nixpkgs input

Minimum acceptable: 6/8
