# Quality Rubric — Task 5 (musl-targeting Containerfile)

Evaluate the generated Containerfile on:

1. **Multi-stage build** (0-2): Does it use at least 2 stages?
   - 2: At least 2 FROM statements, with the builder stage compiling the Rust binary
   - 1: Two FROM statements but the first stage doesn't actually build
   - 0: Single-stage build

2. **musl target** (0-2): Is the musl target used for compilation?
   - 2: `x86_64-unknown-linux-musl` target specified in build command or via RUSTFLAGS/config
   - 1: musl mentioned but target string incomplete or incorrect
   - 0: musl not used (dynamic linking)

3. **scratch final stage** (0-2): Does the runtime image use FROM scratch?
   - 2: Last FROM is `FROM scratch`
   - 1: Last FROM is a minimal image (Alpine, distroless) but not scratch
   - 0: Full OS image as runtime base

4. **CA certificates** (0-2): Are CA certificates included in the runtime image?
   - 2: COPY of `/etc/ssl/certs/ca-certificates.crt` or ca-certificates package installed in runtime
   - 1: CA certs mentioned in comments but not actually copied
   - 0: No CA certificates (HTTPS calls would fail)

Minimum acceptable: 6/8
