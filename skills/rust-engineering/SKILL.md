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

## Principles

- **The compiler is your ally** -- ownership, borrowing, and lifetimes prevent categories of bugs
- **If it compiles, it's probably correct** -- encode invariants in types
- **Make illegal states unrepresentable** -- use enums for closed variants, newtypes for domain meaning
- **Parse, don't validate** -- convert unstructured input into typed structures at the boundary
- **Zero-cost abstractions** -- iterators, traits, and generics compile to the same code you'd write by hand

## Standards

- **Lints**: Use `edition = "2024"`. Apply clippy `pedantic` at workspace level.
- **Error Handling**: Use `thiserror` for libraries, `anyhow` for binaries.
- **Type Design**: Use Newtypes and `impl Trait` where possible.
- **Full Reference**: Read `docs/rust-engineering-patterns.md` for our specific patterns, Justfile tasks, and musl static linking instructions.

## Workflow

1. `cargo check` -> 2. `cargo clippy` -> 3. `cargo test` -> 4. `cargo build`

## Compiler-Driven Development (CDD)

Model the domain in types first. Let the compiler reject invalid programs. For complex lifecycle or state transitions, refer to the Pattern Library in `docs/rust-engineering-patterns.md`.

### Testing Hierarchy

| Layer | Tool | What it proves |
|-------|------|----------------|
| 1 — Compiler | `cargo check` | Invalid states don't compile |
| 2 — Lints | `cargo clippy` | Idiomatic patterns, no obvious bugs |
| 3 — Property tests | `proptest` | Invariants hold for arbitrary inputs |
| 4 — Unit/Integration | `cargo test` | Business logic and interaction |

<restrictions>

## Anti-Patterns

- **Never** use `.unwrap()` in library code. Use `Result` or `.expect("reason")` in tests.
- **Avoid** `String` where `&str` suffices.
- **Do not** use `#[allow(clippy::...)]` without a `// reason:` comment.
- **Minimize** public API; start private, expose deliberately.
- **Do not** accept compiler silence as full correctness proof; write property and unit tests.

</restrictions>
