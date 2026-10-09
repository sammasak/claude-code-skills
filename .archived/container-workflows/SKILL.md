---
name: container-workflows
description: "Use when building, scanning, tagging, or pushing a container image, or writing a Containerfile/Dockerfile for a homelab service."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Container Workflows (homelab)

## Registry and references

- Registry: zot at `registry.sammasak.dev` (Harbor is retired). App images go under `registry.sammasak.dev/lab/<app>`; also `agents/` and `components/` namespaces exist.
- Auth: `~/.config/containers/auth.json` (see `credentials`).
- Tag with the short git SHA; GitOps manifests reference the image by `@sha256:` digest (see `~/homelab-gitops/apps/_template`). `latest` is never deployed.
- Repos on `~/devenv-platform` can render the image from `platform.services` via `devenv container build <name>` instead of a hand-written Containerfile.

## Tooling on this host

buildah, trivy and podman are not on PATH; skopeo is. Run them through nix:

```bash
nix run nixpkgs#buildah -- build -t localhost/<app>:$(git rev-parse --short HEAD) .
skopeo copy containers-storage:localhost/<app>:<sha> docker-archive:/tmp/<app>.tar:<app>:<sha>
nix run nixpkgs#trivy -- image --input /tmp/<app>.tar --severity HIGH,CRITICAL --exit-code 1
skopeo copy containers-storage:localhost/<app>:<sha> docker://registry.sammasak.dev/lab/<app>:<sha>
```

## Known traps

- trivy needs a **docker-archive** export; an oci-archive fails with "manifest.json not found".
- Rootless `podman run` is broken here (no netavark). Inspect image contents with `nix shell nixpkgs#buildah -c buildah unshare` + `buildah mount` instead.
- Pinned base digests go stale: one that scanned clean months ago now trips HIGH CVEs. At every build, re-scan and bump the `FROM ...@sha256:` digest rather than lowering the gate. Do not copy an old app's pinned digest blindly.
- Static sites: copy the `apps/herman-web` pattern (`nginx-unprivileged`, uid 101).
- Rust: static musl binary on `FROM scratch` plus CA certs. Python: see `python-engineering`.
