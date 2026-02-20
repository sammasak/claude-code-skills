---
name: rust-engineering
description: "Use when writing Rust code, configuring Cargo workspaces, setting up clippy lints, designing error handling, or optimizing build profiles. Guides compiler-driven development and idiomatic Rust patterns."
allowed-tools: Bash, Read, Grep, Glob
---

# Rust Engineering

Compiler-driven development: leverage Rust's type system to eliminate bugs before runtime.

## Principles

- **The compiler is your ally** -- ownership, borrowing, and lifetimes prevent whole categories of bugs
- **If it compiles, it's probably correct** -- encode invariants in types so invalid programs fail to compile
- **Make illegal states unrepresentable** -- use enums for closed variants, newtypes for domain meaning
- **Parse, don't validate** -- convert unstructured input into typed structures at the boundary
- **Zero-cost abstractions** -- iterators, traits, and generics compile to the same code you'd write by hand

## Standards

New projects should use `edition = "2024"` (stable since Rust 1.85.0, Feb 2025).

### Lints

Application crates: add `#![forbid(unsafe_code)]` or use the Cargo.toml equivalent below. Clippy config in `Cargo.toml`:

```toml
[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
```

Member crates opt in with `[lints] workspace = true` in their own `Cargo.toml`.

Use `-D warnings` in CI to promote to errors. Cherry-pick `nursery` lints individually rather than enabling the whole group. Enforce `rustfmt` in CI -- no exceptions.

### Error Handling

| Context | Crate | Pattern |
|---------|-------|---------|
| Libraries | `thiserror` | Typed error enums with `#[error]` derive |
| Binaries | `anyhow` | Context chains via `.context("what failed")` |

### Type Design

- **Newtype pattern** -- never pass raw primitives across boundaries:
  ```rust
  struct UserId(Uuid);
  struct EmailAddress(String); // validated at construction
  ```
- Prefer `impl Trait` over `dyn Trait` where the concrete type is known at compile time
- Use `[workspace.dependencies]` to deduplicate versions across crates:
  ```toml
  [workspace.dependencies]
  serde = { version = "1", features = ["derive"] }
  [dependencies]
  serde = { workspace = true }
  ```

## Workflow

1. `cargo check` -- type feedback in seconds
2. `cargo clippy` -- lint pass
3. `cargo test` -- correctness
4. `cargo build` -- artifact

### Release Profile

```toml
[profile.release]
opt-level = 3        # default: speed; use "z" for binary size
lto = true           # or lto = "thin" for faster builds
codegen-units = 1
panic = "abort"
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
image:  buildah build -t myapp:latest .
```

### Dockerfile (multi-stage, musl static linking)

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

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/)
- [Error Handling in Rust](https://burntsushi.net/rust-error-handling/) -- BurntSushi
- [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/index.html)
