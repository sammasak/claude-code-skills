# Task: Set up correct Cargo.toml lint configuration

## Context
You are starting a new Rust API project as a Cargo workspace.
The project should follow the rust-engineering skill's standards.

## Your Task
Write the `[workspace.lints.rust]` and `[workspace.lints.clippy]` sections for a production
Rust API workspace. Requirements:
- Forbid unsafe code workspace-wide
- Enable all clippy lints at warn level
- Enable pedantic at warn level
- Do NOT enable the entire nursery group (pick specific lints individually)
- Use the priority system to allow pedantic to override all

Also write the corresponding `[lints]` stanza for a member crate to opt in.

Write the TOML configuration to `/tmp/eval-output/lints.toml`.
