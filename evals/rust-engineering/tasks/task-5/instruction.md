# Task: Write a musl-targeting Containerfile

## Context
You have a Rust API binary (`workstation-api`) that needs to run as a minimal container
image. The target environment is an Alpine-based runner that will build, and the final
image should be `FROM scratch` (no OS at all).

Requirements:
- Multi-stage build: builder (Alpine with Rust) → runtime (scratch)
- Target: `x86_64-unknown-linux-musl`
- Include CA certificates in the runtime image (needed for HTTPS calls)
- Set entrypoint to `/api`
- The binary is built at: `target/x86_64-unknown-linux-musl/release/workstation-api`

## Your Task
Write the complete Containerfile to `/tmp/eval-output/Containerfile`.
It must follow the multi-stage pattern from the rust-engineering skill.
