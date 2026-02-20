# Review: rust-engineering

## Score: 6/10

The skill file demonstrates strong Rust knowledge and covers the right conceptual territory, but it has several outdated patterns, a few technical inaccuracies, and notable omissions that need correction for a 2026-era guide.

## Findings

### Accurate
- **Principles section is excellent.** "The compiler is your ally," "make illegal states unrepresentable," "parse, don't validate," and "zero-cost abstractions" are timeless Rust principles and well-articulated.
- **Error handling guidance is correct.** The `thiserror` for libraries / `anyhow` for binaries split remains the consensus recommendation as of early 2026. Both crates are actively maintained by dtolnay.
- **Newtype pattern** is correctly described with good examples (`UserId(Uuid)`, `EmailAddress(String)`).
- **`impl Trait` vs `dyn Trait` guidance** is accurate.
- **Workspace dependency deduplication** via `[workspace.dependencies]` is correctly shown with valid TOML syntax.
- **Development cycle** (`cargo check` -> `clippy` -> `test` -> `build`) is a well-known and recommended workflow.
- **Workspace organization** pattern (core/api/worker) is idiomatic and well-described.
- **Anti-patterns table** is comprehensive and accurate -- all entries are valid, especially the guidance on `.unwrap()`, `clone()` to silence borrow checker, and minimizing `pub`.
- **`axum` as HTTP framework** is still the right choice. It remains the dominant async web framework in Rust.
- **`kube-rs` as Kubernetes client** is still the go-to. It is now a CNCF Sandbox project and at version 3.0.1.
- **`tower` for middleware** is correct and tower-native integration with axum is a key selling point.
- **`utoipa` for OpenAPI** is still the leading choice at version 5.4.0, supporting OpenAPI 3.1 spec.
- **`just` as task runner** is a reasonable recommendation. It has 30,000+ GitHub stars and is widely used in the Rust ecosystem.

### Issues

#### 1. No mention of Rust Edition 2024
- **What it says:** No edition is mentioned anywhere.
- **What it should say:** New projects should use `edition = "2024"` (stable since Rust 1.85.0, February 2025). This is the latest edition and the default for `cargo new`. Key features include let chains, refined RPIT lifetime capture rules, `unsafe extern` blocks, `unsafe_op_in_unsafe_fn` warn-by-default, and resolver v3 as the default.
- **Source:** [Announcing Rust 1.85.0 and Rust 2024](https://blog.rust-lang.org/2025/02/20/Rust-1.85.0/)

#### 2. Clippy lint configuration is missing `priority` and uses problematic levels
- **What it says:**
  ```toml
  [workspace.lints.clippy]
  all = "deny"
  pedantic = "warn"
  nursery = "warn"
  ```
- **Problems:**
  1. **Missing `priority` field.** Without `priority = -1` on group-level entries, Cargo will raise `lint_groups_priority` warnings/errors because individual lint overrides (at default priority 0) cannot take precedence over groups at the same priority. The correct syntax requires `{ level = "...", priority = -1 }` for group entries.
  2. **`all = "deny"` is aggressive.** `clippy::all` includes `correctness`, `suspicious`, `complexity`, `perf`, and `style`. Denying all of these (especially `style`, which is the "most opinionated warn-by-default group") makes it very hard to iterate -- any style quibble becomes a hard compile error. The more common practice is `warn` for the group with `-D warnings` in CI.
  3. **`nursery = "warn"` is risky as a blanket group.** Clippy docs explicitly state nursery "contains lints which are buggy or need more work" and recommend cherry-picking rather than enabling the whole group.
  4. **Missing `cargo` lint group.** The `clippy::cargo` group provides useful checks for `Cargo.toml` quality (especially for published crates) and is worth mentioning.
- **What it should say:**
  ```toml
  [workspace.lints.clippy]
  all = { level = "warn", priority = -1 }
  pedantic = { level = "warn", priority = -1 }
  # nursery: cherry-pick individual lints rather than enabling the whole group
  ```
  With `-D warnings` on the CLI in CI to promote warnings to errors.
- **Source:** [Clippy's Lints documentation](https://doc.rust-lang.org/stable/clippy/lints.html), [RFC 3389](https://rust-lang.github.io/rfcs/3389-manifest-lint.html)

#### 3. `unsafe_code` lint should be in `[workspace.lints.rust]`, not just a source attribute
- **What it says:** `#![forbid(unsafe_code)]` as a crate-level attribute.
- **What it should say:** While `#![forbid(unsafe_code)]` is still valid, the modern approach (since Rust 1.74) is to configure this in `Cargo.toml` alongside the other lint settings:
  ```toml
  [workspace.lints.rust]
  unsafe_code = "forbid"
  ```
  This centralizes all lint configuration in one place and can be shared across the workspace. Both approaches should be mentioned.
- **Source:** [The Cargo Book - Profiles](https://doc.rust-lang.org/cargo/reference/profiles.html)

#### 4. Dockerfile example has a critical flaw -- `FROM scratch` without static linking
- **What it says:**
  ```dockerfile
  FROM rust:1-slim AS builder
  ...
  RUN cargo build --release --bin api
  FROM scratch
  COPY --from=builder /src/target/release/api /api
  ```
- **Problem:** `rust:1-slim` uses glibc, so `cargo build --release` produces a dynamically-linked binary. Copying this into `FROM scratch` (which has no libc) will fail at runtime with "no such file or directory." The binary must be statically linked via musl, or the final stage must use a distro with glibc (e.g., `gcr.io/distroless/static` or `alpine`).
- **What it should say:** Either:
  - Use `rust:1-alpine` + `musl-dev` and build with `--target x86_64-unknown-linux-musl` for a true `FROM scratch` image, or
  - Use `gcr.io/distroless/cc-debian12` or `distroless/static` as the final stage instead of `scratch`.
  - Mention that musl builds may need jemalloc or mimalloc as the global allocator due to musl's default allocator performance issues.
  - Mention that `FROM scratch` lacks CA certificates, so HTTPS-calling services need certs copied in (or use `distroless/static`).
- **Source:** [How to Create Minimal Docker Images for Rust Binaries (2026)](https://oneuptime.com/blog/post/2026-01-07-rust-minimal-docker-images/view)

#### 5. `buildah bud` is the legacy alias
- **What it says:** `buildah bud -t myapp:latest .`
- **What it should say:** `buildah build -t myapp:latest .` -- `buildah build` is the canonical command name. `bud` (build-using-dockerfile) still works as an alias but all official documentation has migrated to `buildah build`.
- **Source:** [buildah-build man page](https://github.com/containers/buildah/blob/main/docs/buildah-build.1.md)

#### 6. Release profile `opt-level = "z"` presented as default without context
- **What it says:**
  ```toml
  [profile.release]
  opt-level = "z"       # or 3 for speed over size
  ```
- **Problem:** Presenting `opt-level = "z"` as the primary choice is opinionated and only appropriate for size-constrained targets (embedded, WASM, minimal containers). For most server applications and CLI tools, `opt-level = 3` (the Cargo default for release) is better. The comment "(or 3 for speed over size)" is backwards in emphasis -- speed should be the default, size the exception.
- **What it should say:** Show two named profiles or present `opt-level = 3` as the default with `"z"` as the size-optimized variant. Also consider recommending `lto = "thin"` as a balanced alternative to `lto = true` (fat LTO), since thin LTO provides ~80% of the benefit with ~50% faster compilation. Additionally, `panic = "abort"` is a common release optimization that is not mentioned.
- **Source:** [The Rust Performance Book - Build Configuration](https://nnethercote.github.io/perf-book/build-configuration.html)

#### 7. Clippy reference URL returns 404
- **What it says:** `https://rust-lang.github.io/rust-clippy/master/lints.html`
- **Problem:** This URL returns a 404. The correct URL is `https://rust-lang.github.io/rust-clippy/master/index.html`.
- **Source:** Verified by direct fetch -- `lints.html` does not exist; the lint browser is at `index.html`.

#### 8. BurntSushi blog URL redirects
- **What it says:** `https://blog.burntsushi.net/rust-error-handling/`
- **Problem:** This URL returns a 302 redirect to `https://burntsushi.net/rust-error-handling/`. While the redirect works, the canonical URL should be used.
- **Source:** Verified by direct fetch -- returns 302 to the new domain.

### Missing

#### 1. Rust Edition 2024 guidance
As noted above, the skill should specify that new projects should use `edition = "2024"` and briefly mention the key edition changes (let chains, unsafe extern blocks, resolver v3 default). This is a major omission since the edition shipped a year ago.

#### 2. `[workspace.lints.rust]` section
The skill only shows `[workspace.lints.clippy]` but does not show the `[workspace.lints.rust]` section for rustc lints like `unsafe_code`. A complete workspace lint configuration should show both:
```toml
[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
```

And in member crates:
```toml
[lints]
workspace = true
```

#### 3. `panic = "abort"` in release profile
For binaries (not libraries), `panic = "abort"` eliminates unwinding infrastructure, reducing binary size by 10-20% and slightly improving performance. This is a standard release optimization that should be mentioned.

#### 4. `serde` and `tokio` patterns
The skill mentions `serde` and `tokio` in the workspace dependencies example but provides no guidance on their idiomatic usage. Given how central these crates are, even a brief note on common patterns (e.g., `#[derive(Serialize, Deserialize)]`, `#[tokio::main]`) would add value.

#### 5. Async patterns
No guidance on async Rust patterns beyond the implicit use of axum. For a production-focused skill, mentioning structured concurrency with `tokio::select!`, graceful shutdown patterns, and `tower::Service` composition would be valuable.

#### 6. Testing patterns
The anti-patterns table mentions `.expect("reason")` in tests, but there is no dedicated testing section. Idiomatic Rust testing patterns (unit tests in `#[cfg(test)]` modules, integration tests in `tests/`, `#[should_panic]`, `proptest`/`quickcheck` for property testing, `insta` for snapshot testing) are important for a production engineering skill.

#### 7. `cargo-deny` or supply chain security
No mention of `cargo-deny` or `cargo-audit` for dependency auditing and license compliance. These are standard in production Rust projects.

#### 8. Tracing/observability stack
The skill mentions tower middleware for "tracing" but does not name the `tracing` crate ecosystem (`tracing`, `tracing-subscriber`, `tracing-opentelemetry`), which is the de facto standard for structured logging and distributed tracing in Rust.

#### 9. `cargo-xtask` as an alternative to `just`
The `cargo-xtask` pattern (used by rust-analyzer, helix, and Cargo itself) is a significant alternative to `just` for Rust-only projects. It requires no external tool installation and tasks are written in Rust. Worth a brief mention.

#### 10. `distroless` or `chainguard` as `FROM scratch` alternatives
As noted in the Dockerfile issue, `distroless/static` or `chainguard/static` images are better `FROM scratch` alternatives for most production use cases because they include CA certificates, timezone data, and a non-root user -- with nearly the same minimal attack surface.

### References Check

| Reference | Status | Notes |
|-----------|--------|-------|
| [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) | **Valid** | Active, maintained by Rust library team. |
| [Rust Performance Book](https://nnethercote.github.io/perf-book/) | **Valid** | Active, Nicholas Nethercote still maintains it (updates through Dec 2025). |
| [Rust Design Patterns](https://rust-unofficial.github.io/patterns/) | **Valid** | Active, new pattern added December 2025. |
| [Error Handling in Rust](https://blog.burntsushi.net/rust-error-handling/) | **Redirects** | Returns 302 to `https://burntsushi.net/rust-error-handling/`. Content is still there and relevant, but the URL should be updated to the canonical `burntsushi.net` domain. The post itself is from 2015 (updated 2020) and while foundational, is showing its age. |
| [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/lints.html) | **404 -- Broken** | The correct URL is `https://rust-lang.github.io/rust-clippy/master/index.html`. |

### Recommendations

1. **Add Rust Edition 2024 guidance.** Specify `edition = "2024"` in the workspace Cargo.toml example and briefly note key edition features.

2. **Fix the Clippy lint configuration.** Use `priority = -1` on group entries, switch `all` from `"deny"` to `"warn"`, add a note that nursery should be cherry-picked rather than blanket-enabled, and show the `[workspace.lints.rust]` section alongside `[workspace.lints.clippy]`. Show `-D warnings` as the CI enforcement mechanism.

3. **Fix the Dockerfile example.** Either switch to a musl-based static build or use `distroless/static` as the final stage. The current example will fail at runtime.

4. **Update `buildah bud` to `buildah build`.** Simple rename to use the canonical command.

5. **Fix the release profile.** Present `opt-level = 3` as the default for performance, `"z"` as the size-optimized variant. Add `panic = "abort"` for binaries. Mention `lto = "thin"` as a balanced alternative.

6. **Fix broken/stale reference links.** Update the Clippy lint URL to `index.html` and the BurntSushi blog URL to the canonical `burntsushi.net` domain.

7. **Add a testing section.** Cover unit test modules, integration tests, and property/snapshot testing crates.

8. **Add a brief observability section.** Mention the `tracing` ecosystem as the standard for structured logging.

9. **Add `cargo-deny` / `cargo-audit` mention.** Supply chain security is a production requirement.

10. **Consider mentioning `error-stack` or `snafu`** as alternatives in the error handling section for teams with more complex error propagation needs, while keeping `thiserror`/`anyhow` as the primary recommendation.
