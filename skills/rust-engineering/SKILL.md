---
name: rust-engineering
description: "Use when writing Rust code, configuring Cargo workspaces, setting up clippy lints, designing error handling, or optimizing build profiles. Guides compiler-driven development and idiomatic Rust patterns."
allowed-tools: Bash Read Grep Glob
---

# Rust Engineering

Compiler-driven development: leverage Rust's type system to eliminate bugs before runtime.

## Principles

- **The compiler is your ally** -- ownership, borrowing, and lifetimes prevent whole categories of bugs; work with them, not around them
- **If it compiles, it's probably correct** -- encode invariants in types so invalid programs fail to compile
- **Make illegal states unrepresentable** -- use enums for closed variants, newtypes for domain meaning
- **Parse, don't validate** -- convert unstructured input into typed structures at the boundary, then trust the types
- **Zero-cost abstractions** -- high-level patterns (iterators, traits, generics) compile to the same code you'd write by hand

## Standards

### Lints

All application crates: `#![forbid(unsafe_code)]`

Clippy configuration in `Cargo.toml`:

```toml
[workspace.lints.clippy]
all = "deny"
pedantic = "warn"
nursery = "warn"
```

Enforce `rustfmt` in CI -- no exceptions.

### Error Handling

| Context | Crate | Pattern |
|---------|-------|---------|
| Libraries | `thiserror` | Typed error enums with `#[error]` derive |
| Binaries | `anyhow` | Context chains via `.context("what failed")` |

### Type Design

- **Newtype pattern** for domain types -- never pass raw primitives across boundaries:
  ```rust
  struct UserId(Uuid);
  struct EmailAddress(String); // validated at construction
  ```
- Prefer `impl Trait` over `dyn Trait` where the concrete type is known at compile time
- Use `[workspace.dependencies]` to deduplicate versions across crates:
  ```toml
  # workspace Cargo.toml
  [workspace.dependencies]
  serde = { version = "1", features = ["derive"] }
  tokio = { version = "1", features = ["full"] }

  # crate Cargo.toml
  [dependencies]
  serde = { workspace = true }
  ```

## Workflow

Development cycle -- fast feedback first:

1. `cargo check` -- type feedback in seconds
2. `cargo clippy` -- lint pass
3. `cargo test` -- correctness
4. `cargo build` -- artifact

### Release Profile

```toml
[profile.release]
opt-level = "z"       # or 3 for speed over size
lto = true
codegen-units = 1
strip = true
```

### Workspace Organization

```
workspace/
  crates/
    core/       # shared types, traits, error definitions
    api/        # thin binary -- depends on core
    worker/     # thin binary -- depends on core
  Cargo.toml    # workspace root with [workspace.dependencies]
```

Shared types live in the `core` crate. Binary crates are thin wiring layers.

## Patterns We Use

| Concern | Choice | Why |
|---------|--------|-----|
| HTTP services | `axum` | Tower-native, ergonomic extractors |
| Kubernetes client | `kube-rs` | First-class async, derive-based CRDs |
| Cross-cutting concerns | `tower` middleware | Layers for auth, tracing, rate-limiting |
| OpenAPI generation | `utoipa` | Derive macros keep spec next to code |
| Task runner | `just` | Language-agnostic, simple syntax |
| Container images | Multi-stage Docker with `FROM scratch` | Minimal attack surface, small images |
| Rootless builds | `buildah` | No daemon, OCI-compliant |

### Justfile

```just
check:  cargo check --workspace
lint:   cargo clippy --workspace -- -D warnings
test:   cargo test --workspace
build:  cargo build --release
image:  buildah bud -t myapp:latest .
```

### Dockerfile (multi-stage, `FROM scratch`)

```dockerfile
FROM rust:1-slim AS builder
WORKDIR /src
COPY . .
RUN cargo build --release --bin api

FROM scratch
COPY --from=builder /src/target/release/api /api
ENTRYPOINT ["/api"]
```

## Anti-Patterns

| Do Not | Do Instead |
|--------|------------|
| `.unwrap()` in library code | Return `Result` with `?`, or `.expect("reason")` in tests |
| `String` where `&str` suffices | Accept `&str` or `impl AsRef<str>` to avoid allocation |
| `clone()` to silence the borrow checker | Understand the ownership issue; restructure code |
| `#[allow(clippy::...)]` without comment | Add a `// reason:` comment or fix the lint |
| `pub` on everything | Minimize public API; start private, expose deliberately |
| `Box<dyn Error>` in libraries | Define typed errors with `thiserror` |
| Stringly-typed APIs | Use enums and newtypes for type safety |

## References

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) -- naming, interoperability, documentation
- [Rust Performance Book](https://nnethercote.github.io/perf-book/) -- profiling, allocation, compile times
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/) -- idioms, patterns, anti-patterns
- [Error Handling in Rust](https://blog.burntsushi.net/rust-error-handling/) -- comprehensive treatment by BurntSushi
- [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/lints.html) -- searchable lint reference
