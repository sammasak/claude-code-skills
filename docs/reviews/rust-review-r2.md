# Re-Review: rust-engineering

## Previous Score: 6/10
## New Score: 9/10

The fixes address all eight originally reported issues and several of the "missing" items. The skill file is now technically accurate, concise, and reflects the state of the Rust ecosystem as of early 2026. Two minor issues remain that prevent a perfect score.

## Issues Fixed

### 1. Rust Edition 2024 -- FIXED
The skill now includes: "New projects should use `edition = "2024"` (stable since Rust 1.85.0, Feb 2025)." This is accurate and prominently placed.

### 2. Clippy lint configuration -- FIXED
The updated configuration is correct:
```toml
[workspace.lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
```
- `priority = -1` is present on group entries, preventing `lint_groups_priority` errors.
- `all` is now `warn` instead of `deny`, which is the sensible default.
- `nursery` is no longer blanket-enabled; the skill says "Cherry-pick `nursery` lints individually rather than enabling the whole group."
- `-D warnings` in CI is mentioned as the enforcement mechanism.

All four sub-problems from the original review are resolved.

### 3. `unsafe_code` lint in `[workspace.lints.rust]` -- FIXED
The skill now shows:
```toml
[workspace.lints.rust]
unsafe_code = "forbid"
```
alongside the Clippy lints, and also mentions the `#![forbid(unsafe_code)]` attribute as an alternative. Both approaches are presented, which is correct.

### 4. Dockerfile -- FIXED
The Dockerfile has been completely rewritten with musl static linking:
```dockerfile
FROM rust:1-alpine AS builder
RUN apk add --no-cache musl-dev
WORKDIR /src
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl --bin api

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/api /api
ENTRYPOINT ["/api"]
```
- Uses `rust:1-alpine` with `musl-dev`, which is the correct base for static musl builds.
- Explicitly specifies `--target x86_64-unknown-linux-musl` and the corresponding output path. (On `rust:1-alpine` the host target is already musl, so `--target` is technically redundant, but being explicit is acceptable and arguably clearer about intent.)
- CA certificates are copied into the scratch image, addressing the HTTPS issue from the original review.
- The heading now reads "multi-stage, musl static linking" which accurately describes the approach.

### 5. `buildah bud` -> `buildah build` -- FIXED
The Justfile now shows `buildah build -t myapp:latest .`, using the canonical command name.

### 6. Release profile `opt-level` -- FIXED
The release profile now presents `opt-level = 3` as the default with a comment noting `"z"` as the size-optimized alternative:
```toml
opt-level = 3        # default: speed; use "z" for binary size
```
Additionally, `panic = "abort"` has been added, which was called out in both Issue 6 and Missing Item 3 from the original review. The profile also retains `lto = true`, `codegen-units = 1`, and `strip = true`. This is a solid, well-commented release profile.

### 7. Clippy reference URL -- FIXED
Updated from the broken `lints.html` to the correct `index.html`:
`https://rust-lang.github.io/rust-clippy/master/index.html`
Verified: this URL loads correctly and displays the Clippy lint browser (804 lints).

### 8. BurntSushi blog URL -- FIXED
Updated from `blog.burntsushi.net` to the canonical `burntsushi.net` domain:
`https://burntsushi.net/rust-error-handling/`
Verified: this URL loads directly without redirect.

## Previously Missing Items -- Status

| Missing Item | Status | Notes |
|---|---|---|
| Rust Edition 2024 guidance | **Added** | Covered in Standards section. |
| `[workspace.lints.rust]` section | **Added** | Shows `unsafe_code = "forbid"`. |
| `panic = "abort"` in release profile | **Added** | Present in the release profile block. |
| `serde` and `tokio` patterns | Not added | Remains absent. Acceptable -- the skill is already well-scoped. |
| Async patterns | Not added | Remains absent. Reasonable omission for a general Rust skill. |
| Testing patterns | Not added | Remains absent. Would still add value but not critical. |
| `cargo-deny` / supply chain security | Not added | Remains absent. |
| Tracing/observability stack | Not added | Remains absent. The anti-patterns table mentions `tracing` implicitly via tower middleware. |
| `cargo-xtask` alternative | Not added | Remains absent. |
| `distroless` / `chainguard` alternatives | Not added | Remains absent, but the CA certificate copy addresses the main practical concern with `FROM scratch`. |

The missing items that were not added are all "nice to have" enhancements. The three most impactful ones (edition, workspace.lints.rust, panic=abort) were all added. The skill is a focused guide, not a comprehensive reference, so the remaining omissions are acceptable.

## Remaining Issues

### 1. No `lints.workspace = true` example for member crates (Minor)
The skill shows `[workspace.lints.rust]` and `[workspace.lints.clippy]` in the workspace root, but does not show how member crates opt in:
```toml
[lints]
workspace = true
```
Without this in each member crate's `Cargo.toml`, the workspace-level lint configuration has no effect. This was noted in the original review's Missing Item 2 and is partially fixed (the workspace-level config is there, but the member-crate opt-in is absent). The `[workspace.dependencies]` section already shows the member-crate pattern (`serde = { workspace = true }`), so adding the lint equivalent would be consistent.

### 2. `lto = true` without mention of `lto = "thin"` alternative (Minor)
The original review recommended mentioning `lto = "thin"` as a balanced alternative to full (fat) LTO. The updated profile uses `lto = true` (fat LTO), which is correct and produces the smallest/fastest binary, but fat LTO significantly increases compile times. A brief comment noting `"thin"` as a faster-compiling alternative would be helpful for teams with large codebases. This is a minor point since `lto = true` is not wrong -- it is the most aggressive optimization and appropriate for final release builds.

## New Issues Introduced

None. The fixes are clean and do not introduce any new technical inaccuracies or problematic patterns.

## References Check

| Reference | Status |
|---|---|
| [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) | Valid |
| [Rust Performance Book](https://nnethercote.github.io/perf-book/) | Valid |
| [Rust Design Patterns](https://rust-unofficial.github.io/patterns/) | Valid |
| [Error Handling in Rust](https://burntsushi.net/rust-error-handling/) | Valid (canonical URL, no redirect) |
| [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/index.html) | Valid (loads correctly) |

All five reference URLs are valid and load without errors or redirects.

## Final Verdict

The skill file has been substantially improved. All eight reported issues have been addressed correctly, and three of the most impactful missing items have been added. The fixes are technically accurate and do not introduce any new problems. The two remaining issues are minor (missing `[lints] workspace = true` opt-in example, no mention of `lto = "thin"`). The skill is now a solid, accurate, and practical guide for production Rust engineering in 2026.

Score: **9/10** -- one point withheld for the missing `[lints] workspace = true` member-crate opt-in, which is necessary for the workspace lint configuration to actually take effect and could mislead users who follow the guide as written.
