# Rust Engineering Patterns

This document contains detailed patterns, examples, and workflows for Rust development in this project. Refer to this when implementing new features or refactoring existing ones.

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

## Static Linking (musl)

In Nix / buildah environments (claude-worker VMs): use the Containerfile approach below.

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

**If you must use a Nix devShell for musl:**

```nix
let musl = pkgs.pkgsCross.musl64; in
pkgs.mkShell {
  packages = [ musl.buildPackages.rustc musl.buildPackages.cargo pkgs.pkg-config ];
  CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
  CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER =
    "${musl.stdenv.cc}/bin/${musl.stdenv.cc.targetPrefix}cc";
}
```

## CDD Pattern Library

### Newtype — enforce domain meaning and validate at construction

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
```

### Sealed enum — eliminate stringly-typed variants

```rust
#[derive(Clone, Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "PascalCase")]
pub enum RunStrategy {
    Always,
    Halted,
}
```

### Typestate — encode lifecycle in the type system

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
```

### State machine — exhaustive match forces all branches

```rust
enum Phase { Pending, Running, Halted, Failed }

fn handle(phase: Phase) -> &'static str {
    match phase {
        Phase::Pending => "waiting",
        Phase::Running => "active",
        Phase::Halted  => "stopped",
        Phase::Failed  => "error",
    }
}
```

## References

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/)
- [Error Handling in Rust](https://burntsushi.net/rust-error-handling/) -- BurntSushi
- [Clippy Lint List](https://rust-lang.github.io/rust-clippy/master/index.html)
