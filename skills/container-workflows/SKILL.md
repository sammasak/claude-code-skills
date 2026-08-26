---
name: container-workflows
description: "Use when building container images, writing Dockerfiles, pushing to registries, or optimizing image size and security. Guides rootless builds, multi-stage patterns, and supply chain security."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Container Workflows

Build minimal, rootless, reproducible container images and ship them safely to registries.

## Principles

- **Smallest attack surface** — fewest packages = fewest CVEs
- **Rootless builds** — no Docker daemon required (buildah)
- **Separate build and runtime stages** — compilers never reach production
- **Images are immutable** — never exec into a running container; rebuild and redeploy

## Dockerfile Standards

| Rule | Detail |
|---|---|
| Multi-stage | Always — builder compiles, runtime stage runs |
| Runtime base | `FROM scratch` / `cgr.dev/chainguard/static` for static binaries; `*-slim` for interpreted |
| Pin digests | `FROM python:3.13-slim@sha256:...` — never float on mutable tags |
| Non-root USER | `USER nobody` or dedicated UID — never root |
| COPY specific files | Never `COPY . .`; `.dockerignore` is a safety net only |
| HEALTHCHECK | Always define one for orchestrator integration |
| OCI labels | `org.opencontainers.image.source`, `.version`, `.revision`, `.created` |
| Syntax directive | `# syntax=docker/dockerfile:1` at top |

**Secrets:** Never in `ENV`/`ARG`/`COPY` (visible in `docker history`). Use `RUN --mount=type=secret,id=token`.

**Packages:** Always `apt-get install --no-install-recommends`. Combine update+install+clean in one `RUN`. Use `--mount=type=cache` for package manager caches.

## Build-to-Push Workflow

```bash
# Build (rootless)
buildah build -t myapp:$(git rev-parse --short HEAD) .

# Scan — always before push
trivy image myapp:$(git rev-parse --short HEAD)

# Tag: semver + SHA (never only latest)
buildah tag myapp:$(git rev-parse --short HEAD) myapp:1.4.0

# Push
skopeo copy containers-storage:localhost/myapp:1.4.0 docker://registry.example.com/myapp:1.4.0
skopeo copy containers-storage:localhost/myapp:$(git rev-parse --short HEAD) docker://registry.example.com/myapp:$(git rev-parse --short HEAD)
```

**Tag strategy:** `1.4.0` (release, immutable), `a3f9b2c` (SHA, immutable), `latest` (convenience only, never used in prod).

## Patterns We Use

| Choice | Why |
|---|---|
| **buildah + skopeo** | Rootless, daemonless, OCI-native |
| **Harbor** | Private registry with vulnerability scanning and RBAC |
| **`FROM scratch`** for Rust | Statically linked musl — ~5 MB, zero runtime deps |
| **Chainguard/distroless** | CA certs + tzdata + non-root user out of the box |
| **`python:3.x-slim` + uv** | Fast installs, small image |
| **`just` commands** | `just build`, `just scan`, `just push` wrap the cycle |

## Anti-Patterns

**A successful build does not mean a secure image.** Always run `trivy image <name>` before pushing.

| Don't | Do instead |
|---|---|
| Run as root | `USER nobody` or dedicated UID |
| Compilers in runtime image | Multi-stage builds |
| `:latest` in production | Pin semver + digest |
| Secrets via `ENV`/`ARG` | `RUN --mount=type=secret` or runtime injection |
| Docker-in-Docker in CI | Use buildah — rootless, no privileged containers |
