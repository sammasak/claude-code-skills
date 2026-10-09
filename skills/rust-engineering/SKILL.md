---
name: rust-engineering
description: "Use when writing Rust code in a homelab repo, adding crates, changing Cargo workspace lints or profiles, running Rust gates, applying the type pillar (illegal states unrepresentable, newtypes, typed errors), or building a container image from a Rust binary."
allowed-tools: Bash, Read, Grep, Glob
---

# Rust Engineering (homelab conventions)

Standard is ADR-026 + ADR-027 (`~/knowledge/homelab/decisions/`). Reference repo: `~/rust-devenv-template` — copy from it, not from a sibling repo (per-repo specifics like herman's are not portable).

## Dev environment and gates

devenv is the full dev environment (packages, tasks, git hooks); central policy comes from `~/devenv-platform`. Run gates as devenv tasks, never a repo-local `dev` script or a second flake hook owner:

| When | Task |
|---|---|
| pre-commit hook | `devenv tasks run rust:fmt-check` |
| pre-push hook | `devenv tasks run rust:ci` (strict clippy, cargo-deny, rustdoc, nextest + doctests) |
| release/merge | `devenv tasks run rust:verify` (ci + coverage floor) |
| on demand | `rust:bench`, `rust:audit`, `rust:deps`, `rust:mutants` |

Repos with `platform.sdlc` are driven by the `sdlc-pipeline` skill. Toolchain is pinned stable via `rust-toolchain.toml`; no nightly.

## Lints

`[workspace.lints.clippy]` denies `all` + `pedantic` + `nursery` plus the panic-prevention pack (`unwrap_used`, `expect_used`, `indexing_slicing`, `arithmetic_side_effects`, `panic`, `exit`, `as_conversions`, `string_slice`, ...) and `allow_attributes_without_reason`. `clippy.toml` allows unwrap/expect/panic/indexing in tests. Suppress with `#[expect(lint, reason = "...")]`. A `[profile.clippy]` is required (separate artifact dir, avoids the cold-clippy rebuild cliff).

## Preferred crates (ADR-027 type + test pillars)

- Types: private fields + `bon` fallible builder, `secrecy::SecretString` for secrets, `strum` for enum `ALL`/`COUNT`, tagged serde enums, sqlx `query!`.
- Tests: `proptest`, `insta`, `rstest`, `cargo-mutants` (in verify), per-component `*-test-support` fixture crates.
- Services: `axum` + `tower`, `kube-rs` for cluster clients, `thiserror` in libraries.

## Container images

Static musl binary on `FROM scratch` (copy CA certs from the builder). Build with `nix run nixpkgs#buildah -- build`, push with `--authfile` to `registry.sammasak.dev`; re-scan pinned base digests before reuse (trivy wants docker-archive, not oci).
