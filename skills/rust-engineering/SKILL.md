---
name: rust-engineering
description: "Use when writing Rust code, configuring Cargo workspaces, setting up clippy lints, designing error handling, or optimizing build profiles. Guides compiler-driven development and idiomatic Rust patterns. Excludes general Rust language questions without project tooling context (e.g., general async/await advice)."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Rust Engineering

<when_to_use>
Use this skill when writing new Rust code, adding crates, configuring Cargo workspaces or lints, designing error types, choosing async patterns, or building container images from Rust binaries.
</when_to_use>

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

<workflow>

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

### musl static linking — choose the right approach

> **In Nix / buildah environments (claude-worker VMs): use the Containerfile approach below.**
> Do NOT try to set up musl cross-compilation inside a Nix `devShell` — `pkgs.rust` does not exist, and `pkgsCross.musl64` requires precise attribute paths that vary by nixpkgs version. The Containerfile approach is simpler, faster, and always works.

**Containerfile (buildah on NixOS/alpine builder):**

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

**If you must use a Nix devShell for musl** (e.g. CI without Docker), the correct pattern:

```nix
let musl = pkgs.pkgsCross.musl64; in
pkgs.mkShell {
  packages = [ musl.buildPackages.rustc musl.buildPackages.cargo pkgs.pkg-config ];
  CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
  CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER =
    "${musl.stdenv.cc}/bin/${musl.stdenv.cc.targetPrefix}cc";
}
```

Note: `pkgs.rust`, `pkgs.rust.packages`, `pkgs.rustPlatform.rust` do **not** provide a usable toolchain in a devShell. Use `musl.buildPackages.rustc` or add `rust-overlay` as a flake input.

</workflow>

<compiler_driven_development>

## Compiler-Driven Development

The compiler is the first and strongest test. Make invalid states fail to compile before writing a single test.

**Do not accept compiler silence as correctness for business logic. The compiler proves types; tests prove behavior.**

### CDD Cycle

```
1. Model the domain in types (enums, newtypes, typestate)
2. Let the compiler reject invalid programs
3. Fill remaining invariants with property tests (proptest)
4. Cover business logic with unit tests
5. Prove integration with integration tests
```

### Pattern Library

**Newtype — enforce domain meaning and validate at construction:**

```rust
struct SecretName(String);

impl SecretName {
    pub fn new(s: &str) -> Result<Self, String> {
        if s.is_empty() || s.len() > 63 || !s.chars().all(|c| c.is_alphanumeric() || c == '-') {
            return Err(format!("invalid secret name: '{s}'"));
        }
        Ok(Self(s.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}
// Private inner field forces all construction through validator.
```

**Sealed enum — eliminate stringly-typed variants:**

```rust
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "PascalCase")]
pub enum RunStrategy {
    Always,
    Halted,
}
// No runtime validation needed — serde rejects unknown values at deserialization.
```

**Typestate — encode lifecycle in the type system:**

```rust
use std::marker::PhantomData;
struct Light<S>(PhantomData<S>);
struct Off;
struct On;

impl Light<Off> {
    fn turn_on(self) -> Light<On> { Light(PhantomData) }
}
impl Light<On> {
    fn turn_off(self) -> Light<Off> { Light(PhantomData) }
    fn brightness(&self) -> u8 { 100 }
}
// Light<Off>::brightness() does not exist — compiler rejects calling it.
```

**State machine — exhaustive match forces all branches:**

```rust
enum Phase { Pending, Running, Halted, Failed }

fn handle(phase: Phase) -> &'static str {
    match phase {
        Phase::Pending => "waiting",
        Phase::Running => "active",
        Phase::Halted  => "stopped",
        Phase::Failed  => "error",
        // Add a new variant → compiler forces you to handle it here too.
    }
}
```

### Testing Hierarchy

| Layer | Tool | What it proves |
|-------|------|----------------|
| 1 — Compiler | `cargo check` | Invalid states don't compile |
| 2 — Lints | `cargo clippy` | Idiomatic patterns, no obvious bugs |
| 3 — Property tests | `proptest` | Invariants hold for arbitrary inputs |
| 4 — Unit tests | `cargo test --lib` | Business logic correctness |
| 5 — Integration | `cargo test --test` | Component interaction |

### When NOT to Rely on the Compiler

- External system behavior (controller-written status fields, third-party API responses)
- Numeric range invariants (`minutes >= 5`) — enums can't express ranges
- Business rules spanning multiple fields simultaneously
- Timing, ordering, and concurrency properties

For these, write property tests or integration tests. The types looking right is not enough.

</compiler_driven_development>

<restrictions>

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
| Accept compiler silence as full correctness proof | The compiler proves types; tests prove behavior — write property and unit tests for business logic regardless |

</restrictions>

## References

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/)
- [Error Handling in Rust](https://burntsushi.net/rust-error-handling/) -- BurntSushi
- [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/index.html)
