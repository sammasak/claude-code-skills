# Review: container-workflows

## Score: 7/10

A solid, opinionated skill file that covers the core container workflow well. The principles are sound, the Dockerfile examples are structurally correct, and the tooling choices (buildah, skopeo, trivy) remain current. However, there are several technical inaccuracies in commands and examples, some outdated version references, missing coverage of important 2026 conventions (distroless images, Docker Hardened Images, BuildKit attestations, Chainguard as a base image alternative), and the Python Dockerfile example has multiple deviations from current best practices.

---

## Findings

### Accurate

- **Principles section** is excellent. "Smallest attack surface," rootless builds, reproducible layers, separation of build/runtime stages, and immutable images are all correct and well-articulated.
- **Multi-stage builds** are correctly presented as a mandatory pattern. This remains the standard recommendation from Docker, CNCF, and all major container security guides.
- **Pin digests** advice (`FROM python:3.12-slim@sha256:abc123...`) is correct and important. This is a best practice confirmed by Docker docs, SLSA framework, and Chainguard guidance.
- **Non-root USER** requirement is correct. The `USER nobody` or dedicated UID pattern is standard.
- **Secrets handling** is accurate. `RUN --mount=type=secret` is the correct BuildKit mechanism, and the warning about `ENV`/`ARG` visibility in `docker history` is correct.
- **Package management** advice (`--no-install-recommends`, combining RUN layers, cleaning apt lists) is correct and current.
- **buildah + skopeo** as the rootless toolchain is a strong, current recommendation. Buildah v1.42.0 (October 2025) remains actively developed and is the leading rootless/daemonless build tool. Skopeo v1.22.0 remains the standard for registry operations.
- **Trivy** is still the go-to open-source vulnerability scanner. v0.69.0 (January 2026) is current, with a "Next-Gen Trivy" announced for 2026. Grype is correctly mentioned as an alternative.
- **Harbor** remains a strong choice for self-hosted registries. It is a CNCF Graduated project, with v2.15.0 being the latest release. The description is accurate.
- **Version tagging strategy** table (semver, git SHA, latest) is correct and well-presented.
- **Anti-patterns table** is comprehensive and accurate. All entries represent genuine anti-patterns with correct alternatives.
- **OCI labels** recommendation is correct. The `org.opencontainers.image.*` annotation keys are part of the OCI Image Spec v1.1.0 (current as of Feb 2026).
- **SLSA framework** reference is appropriate. SLSA v1.2 was released in late 2025 and remains the current version.
- **One process per container** is correct advice.
- **HEALTHCHECK** recommendation is appropriate for orchestrator integration.
- **`FROM scratch` for static Rust binaries** is a valid and recommended pattern.
- **`python:3.x-slim` + uv** is the correct modern Python container pattern.

### Issues

#### 1. `skopeo inspect` command uses wrong transport (Line 54)

**Currently says:**
```bash
skopeo inspect docker://localhost/myapp:$(git rev-parse --short HEAD)
```

**Problem:** After `buildah build`, the image is stored in local `containers-storage`, not in a Docker daemon or local registry at `localhost`. The `docker://localhost/...` transport would try to contact a registry at localhost, which typically does not exist in a rootless buildah workflow.

**Should say:**
```bash
skopeo inspect containers-storage:localhost/myapp:$(git rev-parse --short HEAD)
```

**Source:** [Skopeo documentation](https://github.com/containers/skopeo/blob/main/docs/skopeo.1.md) -- the `containers-storage:` transport accesses the local Podman/Buildah image store directly.

#### 2. `skopeo copy` command uses wrong source transport (Lines 64-69)

**Currently says:**
```bash
skopeo copy \
  docker://localhost/myapp:1.4.0 \
  docker://registry.example.com/myapp:1.4.0
```

**Problem:** Same issue as above. The source should use `containers-storage:` transport to reference locally-built images.

**Should say:**
```bash
skopeo copy \
  containers-storage:localhost/myapp:1.4.0 \
  docker://registry.example.com/myapp:1.4.0
```

**Source:** [Red Hat documentation on Buildah + Skopeo workflows](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/assembly_running-skopeo-buildah-and-podman-in-a-container)

#### 3. Rust base image version is outdated (Line 95)

**Currently says:**
```dockerfile
FROM rust:1.80-slim@sha256:... AS builder
```

**Problem:** Rust 1.80 was released in mid-2024. The current stable Rust version is 1.93.1 (January 2026). While pinning is correct and the SHA would lock the version, using 1.80 as the example version suggests this hasn't been updated. A skill file should use a reasonably current version in examples.

**Should say:**
```dockerfile
FROM rust:1.93-slim@sha256:... AS builder
```

**Source:** [Rust releases](https://releases.rs/) -- Rust 1.93.0 was released January 22, 2026.

#### 4. Python example uses `--frozen` instead of recommended `--locked` (Line 115)

**Currently says:**
```dockerfile
RUN uv sync --frozen --no-dev
```

**Problem:** `--frozen` blindly trusts the lockfile without verifying it matches `pyproject.toml`. The `--locked` flag is more appropriate for production/deployment as it validates consistency and fails if the lockfile has drifted. The uv documentation recommends `--locked` for deployment pipelines. Using `--frozen` may be necessary in specific Docker layer caching scenarios where project source is not yet available, but the example already has `pyproject.toml` and `uv.lock` copied, so `--locked` would work and be safer.

**Should say:**
```dockerfile
RUN uv sync --locked --no-dev
```

**Source:** [uv documentation on locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/) -- "--locked is more appropriate for deployment pipelines."

#### 5. Python example copies `uv` from `:latest` tag instead of pinned version (Line 112)

**Currently says:**
```dockerfile
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
```

**Problem:** This contradicts the skill's own principle of never floating on mutable tags. The `:latest` tag for the uv image is mutable and will change with every release. The current uv version is 0.10.4 (Feb 2026). The skill should pin to a specific version, ideally with a digest.

**Should say:**
```dockerfile
COPY --from=ghcr.io/astral-sh/uv:0.10@sha256:... /uv /uvx /usr/local/bin/
```

Note: The current best practice also copies `/uvx` alongside `/uv`.

**Source:** [uv Docker integration docs](https://docs.astral.sh/uv/guides/integration/docker/) and [Depot's optimal uv Dockerfile guide](https://depot.dev/docs/container-builds/how-to-guides/optimal-dockerfiles/python-uv-dockerfile)

#### 6. Python example is missing best-practice uv environment variables (Lines 110-125)

**Problem:** The Python Dockerfile example is missing two important environment variables recommended by the uv Docker documentation and multiple community guides:

- `UV_COMPILE_BYTECODE=1` -- Compiles `.pyc` files for faster startup in production.
- `UV_LINK_MODE=copy` -- Ensures files are copied rather than symlinked, which is important in multi-stage builds and container environments.

**Should add in builder stage:**
```dockerfile
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
```

**Source:** [uv Docker guide](https://docs.astral.sh/uv/guides/integration/docker/), [Hynek Schlawack's production Docker + uv article](https://hynek.me/articles/docker-uv/), [Depot optimal Dockerfile guide](https://depot.dev/docs/container-builds/how-to-guides/optimal-dockerfiles/python-uv-dockerfile)

#### 7. Python example should use `python:3.13-slim` (Lines 111, 117)

**Currently says:**
```dockerfile
FROM python:3.12-slim@sha256:...
```

**Problem:** While Python 3.12 is still supported, Python 3.13 has been available since October 2024 and is the current stable release (3.13.11 as of Dec 2025). The official Docker Python images are now based on Debian Trixie 13. For a skill file meant to guide best practices, the example should use the latest stable Python.

**Should say:**
```dockerfile
FROM python:3.13-slim@sha256:...
```

**Source:** [PythonSpeed - best Docker base image for Python (Feb 2026)](https://pythonspeed.com/articles/base-image-python-docker-images/)

Note: This is a minor issue. Python 3.12 is still in active support and is a perfectly valid choice. Mentioning `3.x-slim` generically (as done in the "Patterns We Use" table) is fine.

#### 8. Python example missing `--no-install-project` in dependency layer (Line 115)

**Currently says:**
```dockerfile
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
```

**Problem:** This installs the project itself along with dependencies. Current best practice for Docker layer caching is to first install only dependencies (`--no-install-project`), then copy source code, then install the project. This way, dependencies are cached as a layer and don't rebuild when only source code changes.

**Should say:**
```dockerfile
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project --no-dev
COPY src/ src/
RUN uv sync --locked --no-dev
```

**Source:** [uv Docker guide - "Intermediate layers"](https://docs.astral.sh/uv/guides/integration/docker/), [Depot optimal Dockerfile](https://depot.dev/docs/container-builds/how-to-guides/optimal-dockerfiles/python-uv-dockerfile)

#### 9. Rust example missing CA certificates for HTTPS (Lines 102-106)

**Currently says:**
```dockerfile
FROM scratch
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/myapp /myapp
USER 65534
ENTRYPOINT ["/myapp"]
```

**Problem:** If the Rust binary makes HTTPS requests (extremely common), it needs CA certificates. `FROM scratch` contains nothing at all -- no certificates, no timezone data. A production example should include CA certs, or mention this caveat.

**Should say:**
```dockerfile
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/myapp /myapp
USER 65534
ENTRYPOINT ["/myapp"]
```

Or use `gcr.io/distroless/static` or `cgr.dev/chainguard/static` which include CA certs and a non-root user out of the box.

**Source:** [Multiple Rust + Docker guides](https://oneuptime.com/blog/post/2026-01-07-rust-minimal-docker-images/view) consistently recommend copying CA certificates for scratch-based images.

### Missing

#### 1. Distroless and Chainguard images as runtime base alternatives

The skill mentions `FROM scratch` and `*-slim` but does not discuss distroless images as a middle ground. As of 2026, Chainguard images (`cgr.dev/chainguard/static`, `cgr.dev/chainguard/python`) are widely recommended as production bases. They provide:
- Zero known CVEs with nightly rebuilds
- Built-in CA certificates, timezone data, and non-root users
- SBOM and Sigstore signatures
- SLSA Build Level 2 compliance

The Chainguard link in the References section points to their marketing page but the skill never actually recommends using them as base images. The "Patterns We Use" table should include Chainguard or distroless images alongside `FROM scratch` and `*-slim`.

**Sources:** [Chainguard Academy](https://edu.chainguard.dev/chainguard/chainguard-images/overview/), [Alpine vs Distroless vs Scratch comparison](https://medium.com/google-cloud/alpine-distroless-or-scratch-caac35850e0b)

#### 2. Docker Hardened Images (DHI)

As of late 2025, Docker made its catalogue of 1,000+ hardened container images freely available under Apache 2.0. These are a significant new option (`dhi.io/...`) for base images with reduced CVEs. A current skill file should at least mention them.

**Source:** [InfoQ - Docker Hardened Images](https://www.infoq.com/news/2025/12/docker-hardened-images/)

#### 3. BuildKit cache mounts for package managers

The skill recommends combining apt-get commands in a single RUN but does not mention BuildKit cache mounts, which are a cleaner and more cache-friendly alternative:

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends pkg1 pkg2
```

Similarly, for the uv example, `--mount=type=cache,target=/root/.cache/uv` would speed up rebuilds.

**Source:** [Docker BuildKit documentation](https://docs.docker.com/build/buildkit/)

#### 4. Image attestations (SBOM and provenance)

BuildKit supports `--attest=type=sbom` and `--attest=type=provenance` at build time. Given the skill's emphasis on supply chain security and its reference to SLSA, it should mention build-time attestations as part of the workflow.

**Source:** [Docker attestations documentation](https://docs.docker.com/build/building/best-practices/)

#### 5. Multi-platform builds

The skill does not mention multi-platform/multi-architecture builds (`--platform linux/amd64,linux/arm64`). With ARM-based cloud instances (AWS Graviton, Azure Cobalt, etc.) being mainstream in 2026, this is a notable gap. Both buildah and BuildKit support multi-platform builds.

#### 6. Dockerfile syntax directive

The skill does not mention pinning the BuildKit frontend syntax version:

```dockerfile
# syntax=docker/dockerfile:1
```

This is a Docker best practice that ensures reproducible parsing behavior across BuildKit versions.

**Source:** [Docker best practices](https://docs.docker.com/build/building/best-practices/)

#### 7. `cargo-chef` or Rust dependency caching

The Rust example rebuilds all dependencies on every source change because `Cargo.toml`, `Cargo.lock`, and `src/` are all copied before `cargo build`. In practice, the `cargo-chef` crate or BuildKit cache mounts are used to cache the dependency compilation layer separately.

**Source:** [cargo-chef](https://github.com/LukeMathWalker/cargo-chef)

### References Check

| # | Reference | Status | Notes |
|---|-----------|--------|-------|
| 1 | [Docker best practices](https://docs.docker.com/build/building/best-practices/) | **Valid** | Active, current content |
| 2 | [Buildah documentation](https://buildah.io/) | **Valid** | Active, latest release v1.42.0 announced |
| 3 | [Chainguard images](https://www.chainguard.dev/chainguard-images) | **Valid** | Active, but this links to marketing page. Consider also linking to [Chainguard Academy](https://edu.chainguard.dev/) for technical docs and [images.chainguard.dev](https://images.chainguard.dev/) for the image directory |
| 4 | [SLSA framework](https://slsa.dev/) | **Valid** | Active, current version is v1.2 |
| 5 | [OCI image spec](https://github.com/opencontainers/image-spec) | **Valid** | Active GitHub repo, latest spec is v1.1.0 |
| 6 | [Trivy scanner](https://trivy.dev/) | **Valid** | Active, v0.69.0 current, "Next-Gen Trivy" announced for 2026 |

All six references are valid and current. Consider adding:
- [uv Docker integration guide](https://docs.astral.sh/uv/guides/integration/docker/) -- since uv is a core tool in the Python example
- [Skopeo repository](https://github.com/containers/skopeo) -- since skopeo is a core tool but has no reference link

### Recommendations

1. **Fix the skopeo transport** in both the `inspect` and `copy` commands. Change `docker://localhost/` to `containers-storage:localhost/`. This is the most significant technical inaccuracy in the file.

2. **Pin the uv image tag** in the Python Dockerfile example. Change `ghcr.io/astral-sh/uv:latest` to a pinned version like `ghcr.io/astral-sh/uv:0.10@sha256:...` to be consistent with the skill's own digest-pinning principle.

3. **Update the Python Dockerfile** to follow the latest uv best practices: add `UV_COMPILE_BYTECODE=1` and `UV_LINK_MODE=copy`, use `--locked` instead of `--frozen`, use `--no-install-project` for proper layer caching, and copy `/uvx` alongside `/uv`.

4. **Update Rust version** in the example from `rust:1.80-slim` to `rust:1.93-slim` (or at least a more recent version).

5. **Add CA certificates** to the Rust scratch example, or document the caveat, or recommend `cgr.dev/chainguard/static` as an alternative to bare `scratch`.

6. **Add a "Base Image Selection" section** that covers the spectrum: `scratch` (for static binaries needing nothing), `cgr.dev/chainguard/static` or `gcr.io/distroless/static` (for static binaries needing CA certs/tzdata), `cgr.dev/chainguard/python` or `python:3.x-slim` (for interpreted languages), and mention Docker Hardened Images (`dhi.io`) as a new option.

7. **Add BuildKit cache mounts** to the package management and uv sections. This is a widely adopted pattern that significantly improves build performance.

8. **Add a note about multi-platform builds** given the prevalence of ARM-based infrastructure in 2026.

9. **Add the `# syntax=docker/dockerfile:1` directive** to the example Dockerfiles, since the skill already uses BuildKit features like `--mount=type=secret`.

10. **Add references** for the uv Docker guide and skopeo, since both are core tools mentioned in the skill.

---

*Review conducted: 2026-02-18*
*Reviewer: Claude Opus 4.6*
*Skill file: `/home/lukas/claude-code-skills/skills/container-workflows/SKILL.md`*
