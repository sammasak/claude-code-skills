---
name: kubernetes-gitops
description: "Use when working with Kubernetes clusters, GitOps deployments, Flux reconciliation, Helm releases, or cluster troubleshooting. Guides declarative cluster management and GitOps workflows."
allowed-tools: Bash Read Grep Glob
---

# Kubernetes GitOps

Manage Kubernetes clusters declaratively through Git-driven reconciliation loops.

## Principles

- **Git is the single source of truth** -- the desired state of every cluster lives in version control
- **Pull-based reconciliation** -- the cluster pulls state from Git; CI never pushes to the cluster
- **Drift detection and self-healing** -- the controller continuously converges actual state toward declared state
- **Declarative desired state** -- describe *what*, never script *how*
- **Separation of concerns** -- CI builds and tests artifacts; GitOps deploys them

## Standards

### Repository structure

```
clusters/
  <cluster-name>/          # Flux entrypoint per cluster
    flux-system/
    infrastructure.yaml    # Kustomization ordering infra before apps
    apps.yaml
infrastructure/
  controllers/             # Shared infra (ingress, cert-manager, etc.)
  configs/                 # Cluster-wide configs (PSS, network policies)
apps/
  base/                    # Kustomize bases per app
  overlays/
    staging/
    production/
```

### Kustomization layering

| Layer | Purpose | Example |
|---|---|---|
| `base/` | App defaults, common labels, base manifests | Deployment, Service, HPA |
| `overlays/<env>/` | Env-specific patches, replica counts, resource limits | Production replica bump, CPU limits |
| `clusters/<name>/` | Cluster-specific bindings, Flux orchestration | Dependency ordering, SOPS secret refs |

### HelmRelease pattern

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app
spec:
  interval: 30m
  chart:
    spec:
      chart: app
      version: "1.x"          # semver range, not floating tags
      sourceRef:
        kind: HelmRepository
        name: app-repo
  valuesFrom:
    - kind: ConfigMap
      name: app-values        # keep values in Git, not inline
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
```

### Workload requirements checklist

- [ ] `resources.requests` and `resources.limits` set on every container
- [ ] `readinessProbe` and `livenessProbe` on every Deployment
- [ ] Namespace has a Pod Security Standard label (`enforce: restricted` or `baseline`)
- [ ] ServiceAccount per workload, never `default`
- [ ] NetworkPolicy restricting ingress/egress

## Workflow

### Cluster health check

```bash
kubectl get nodes -o wide                           # node status and versions
kubectl get pods -A --field-selector status.phase!=Running | grep -v Completed  # broken pods
flux get all -A                                     # reconciliation status across all objects
flux get sources all -A                             # source freshness
```

### Force Flux reconciliation

```bash
flux reconcile source git flux-system               # pull latest from Git now
flux reconcile kustomization flux-system --with-source  # reconcile full tree from source
flux reconcile helmrelease <name> -n <ns>            # retry a specific release
```

### Debug a failed HelmRelease

```bash
flux logs --kind=HelmRelease --name=<name> -n <ns>  # controller logs for this release
flux get helmrelease <name> -n <ns>                  # status and last applied revision
helm history <name> -n <ns>                          # release history and rollback candidates
kubectl describe helmrelease <name> -n <ns>          # events and conditions
kubectl get events -n <ns> --sort-by=.lastTimestamp   # recent namespace events
```

### Image update automation

```bash
# 1. Define an ImageRepository (scan registry)
# 2. Define an ImagePolicy (semver/alphabetical filter)
# 3. Mark manifests with `# {"$imagepolicy": "ns:policy"}` comments
# 4. ImageUpdateAutomation commits changes back to Git
flux get images all -A                               # verify scanning and policies
```

## Patterns We Use

| Choice | Over | Why |
|---|---|---|
| **FluxCD** | ArgoCD | Lightweight, no UI overhead, pure K8s CRDs, composable with Kustomize |
| **SOPS + age** | Sealed Secrets / Vault | Encrypted secrets live in Git; age keys are simple to manage; no extra controller |
| **ingress-nginx + cert-manager** | Traefik / manual certs | DNS-01 challenge via Cloudflare; wildcard certs; battle-tested |
| **MetalLB** | cloud LB | Bare-metal clusters need L2/BGP advertisement for LoadBalancer Services |
| **KubeVirt** | separate hypervisor | Run VM workloads alongside containers on the same cluster |
| **Nix flake dev shell** | manual tool install | `nix develop` provides pinned kubectl, helm, flux, sops, age, just |
| **Flux bootstrap via NixOS module** | manual bootstrap | Declarative cluster bootstrapping tied to host configuration |

## Anti-Patterns

- **`kubectl apply` from laptops in production** -- bypasses Git, creates invisible drift
- **Hardcoded mutable image tags** (`:latest`, `:v1`) -- use image automation or pinned digests (`@sha256:...`)
- **Plaintext secrets in Git** -- always encrypt with SOPS; if it was committed in plaintext, rotate the secret
- **Missing resource requests/limits** -- leads to noisy neighbors and OOM kills; set them on every container
- **cluster-admin RBAC for apps** -- scope ServiceAccount permissions to the minimum namespace and verbs
- **Manual drift fixes without updating Git** -- the controller will revert your fix; change Git, let it reconcile
- **Skipping health checks** -- Deployments without probes get traffic before they are ready

## References

- [FluxCD documentation](https://fluxcd.io/flux/)
- [Kubernetes official docs](https://kubernetes.io/docs/)
- [OpenGitOps principles](https://opengitops.dev/)
- [GitOps and Kubernetes](https://www.manning.com/books/gitops-and-kubernetes) (Manning)
- [Flux SOPS integration guide](https://fluxcd.io/flux/guides/mozilla-sops/)
