---
name: container-workflows
description: "Use when building container images, writing Dockerfiles, pushing to registries, or optimizing image size and security. Guides rootless builds, multi-stage patterns, and supply chain security."
allowed-tools: Bash Read Grep Glob
---

# Container Workflows

Build minimal, rootless, reproducible container images and ship them safely to registries.

## Principles

- **Smallest attack surface** — fewest packages = fewest CVEs. Every binary you omit is a vulnerability that can never fire.
- **Rootless builds** — no Docker daemon privilege required at any step.
- **Reproducible layers** — pinned digests and deterministic tooling make builds bit-for-bit repeatable.
- **Separate build and runtime stages** — compilers, headers, and caches never reach production.
- **Images are immutable artifacts** — never exec into or mutate a running container. Rebuild and redeploy.

## Standards

### Dockerfile structure

| Rule | Detail |
|---|---|
| Multi-stage builds | Always. Builder stage compiles; runtime stage runs. |
| Runtime base | `FROM scratch` for static binaries (Rust/Go). `*-slim` for interpreted languages (Python). |
| Pin digests | `FROM python:3.12-slim@sha256:abc123...` — never float on a mutable tag. |
| Non-root USER | Set `USER nobody` or a dedicated UID. Never run as root. |
| COPY specific files | List what you need. Never `COPY . .` — rely on `.dockerignore` as a safety net, not the primary mechanism. |
| One process per container | PID 1 is your service. No supervisord, no sshd alongside. |
| HEALTHCHECK | Always define one for orchestrator integration (`HEALTHCHECK CMD curl -f http://localhost/health`). |
| OCI labels | Annotate with `org.opencontainers.image.source`, `.version`, `.revision`, `.created`. |

### Secrets

- **Never** in `ENV`, `ARG`, or `COPY` — all are visible in `docker history`.
- Use build-time secret mounts: `RUN --mount=type=secret,id=token ...`
- At runtime, mount secrets via orchestrator (Kubernetes Secrets, Vault sidecar).

### Packages

- Always `--no-install-recommends` with `apt-get install`.
- Combine `apt-get update && apt-get install && rm -rf /var/lib/apt/lists/*` in a single `RUN`.

## Workflow

Build-to-push cycle: **build -> inspect -> scan -> tag -> push**.

```bash
# 1. Build (rootless, daemonless)
buildah build -t myapp:$(git rev-parse --short HEAD) .

# 2. Inspect — verify labels, layers, entrypoint
skopeo inspect docker://localhost/myapp:$(git rev-parse --short HEAD)

# 3. Scan for vulnerabilities
trivy image myapp:$(git rev-parse --short HEAD)
# or: grype myapp:$(git rev-parse --short HEAD)

# 4. Tag — always semver + git SHA, never only latest
buildah tag myapp:$(git rev-parse --short HEAD) myapp:1.4.0

# 5. Push to registry
skopeo copy \
  docker://localhost/myapp:1.4.0 \
  docker://registry.example.com/myapp:1.4.0
skopeo copy \
  docker://localhost/myapp:$(git rev-parse --short HEAD) \
  docker://registry.example.com/myapp:$(git rev-parse --short HEAD)
```

### Version tagging strategy

| Tag | Purpose | Mutable? |
|---|---|---|
| `1.4.0` | Release version | No |
| `a3f9b2c` | Git SHA — trace image to exact commit | No |
| `latest` | Convenience only, never depended on in prod | Yes |

## Patterns We Use

| Choice | Why |
|---|---|
| **buildah + skopeo** | Rootless, daemonless, OCI-native. No Docker socket needed. |
| **Harbor** | Private registry with built-in vulnerability scanning and RBAC. |
| **Nix flake dev shells** | Provide buildah, skopeo, trivy — reproducible tooling across machines. |
| **`FROM scratch`** for Rust | Statically linked with musl. Zero runtime dependencies, ~5 MB images. |
| **`python:3.x-slim` + uv** | Fast installs, small image. uv replaces pip for dependency resolution. |
| **`just` commands** | `just build`, `just scan`, `just push` wrap the full cycle. |
| **Flux image automation** | Watches registry for new tags, updates Git manifests, triggers deploy. |

### Minimal Rust example

```dockerfile
FROM rust:1.80-slim@sha256:... AS builder
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src/ src/
RUN rustup target add x86_64-unknown-linux-musl \
    && cargo build --release --target x86_64-unknown-linux-musl

FROM scratch
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/myapp /myapp
USER 65534
ENTRYPOINT ["/myapp"]
```

### Minimal Python example

```dockerfile
FROM python:3.12-slim@sha256:... AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

FROM python:3.12-slim@sha256:...
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY src/ src/
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
ENTRYPOINT ["python", "-m", "myapp"]
```

## Anti-Patterns

| Don't | Do instead |
|---|---|
| Run as root | `USER nobody` or dedicated UID |
| Install compilers in runtime image | Multi-stage: build stage compiles, runtime stage runs |
| Use `latest` in production | Pin semver + digest |
| Secrets via `ENV`/`ARG` | `RUN --mount=type=secret` or runtime injection |
| Skip `.dockerignore` | Maintain it — exclude `.git/`, `target/`, `node_modules/`, `*.env` |
| `apt-get install` without `--no-install-recommends` | Always pass the flag, then clean lists |
| Docker-in-Docker for CI | Use buildah — rootless, no privileged containers needed |
| Commit large images to Git | Push to registry, reference by digest |

## References

- [Docker best practices](https://docs.docker.com/build/building/best-practices/)
- [Buildah documentation](https://buildah.io/)
- [Chainguard images](https://www.chainguard.dev/chainguard-images) — minimal, zero-CVE base images
- [SLSA framework](https://slsa.dev/) — supply chain integrity levels
- [OCI image spec](https://github.com/opencontainers/image-spec)
- [Trivy scanner](https://trivy.dev/)
