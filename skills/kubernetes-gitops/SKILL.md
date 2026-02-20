---
name: kubernetes-gitops
description: "Use when working with Kubernetes clusters, GitOps deployments, Flux reconciliation, Helm releases, or cluster troubleshooting. Guides declarative cluster management and GitOps workflows."
allowed-tools: Bash, Read, Grep, Glob
---

# Kubernetes GitOps

Manage Kubernetes clusters declaratively through Git-driven reconciliation loops.

## Principles

- **Git is the single source of truth** -- desired state lives in version control
- **Pull-based reconciliation** -- the cluster pulls state from Git; CI never pushes
- **Drift detection and self-healing** -- controllers converge actual toward declared state
- **Declarative desired state** -- describe *what*, never script *how*
- **Separation of concerns** -- CI builds artifacts; GitOps deploys them

## Standards

### Repository structure

```
clusters/<cluster>/flux-system/        # Flux entrypoint per cluster
clusters/<cluster>/infrastructure.yaml # Kustomization ordering infra before apps
clusters/<cluster>/apps.yaml
infrastructure/controllers/            # Shared infra (ingress, cert-manager, etc.)
infrastructure/configs/                # Cluster-wide configs (PSS, network policies)
apps/base/                             # Kustomize bases per app
apps/overlays/{staging,production}/
```

### Kustomization layering

| Layer | Purpose | Example |
|---|---|---|
| `base/` | App defaults, common labels, base manifests | Deployment, Service, HPA |
| `overlays/<env>/` | Env-specific patches, replicas, limits | Production replica bump |
| `clusters/<name>/` | Cluster bindings, Flux orchestration | Dependency ordering, SOPS refs |

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
  driftDetection:
    mode: enabled
```

### Workload requirements

- [ ] `resources.requests` and `resources.limits` on every container
- [ ] `readinessProbe` and `livenessProbe` on every Deployment
- [ ] Namespace has Pod Security Standard label (`enforce: restricted` or `baseline`)
- [ ] ServiceAccount per workload, never `default`; NetworkPolicy restricting ingress/egress

## Workflow

### Cluster health check

```bash
flux check                                             # Flux component versions and health
kubectl get nodes -o wide                              # node status and versions
kubectl get pods -A --field-selector status.phase!=Running | grep -v Completed
flux get all -A                                        # reconciliation status
flux get sources all -A                                # source freshness
flux logs --all-namespaces --level=error               # recent error logs across controllers
```

### Force Flux reconciliation

```bash
flux diff kustomization <name>                       # preview changes before reconciliation
flux reconcile source git flux-system               # pull latest from Git now
flux reconcile kustomization flux-system --with-source  # reconcile full tree
flux reconcile helmrelease <name> -n <ns>            # retry a specific release
```

### Flux API migration

```bash
flux migrate -v 2.6 -f .                            # migrate manifests to stable APIs before upgrading
```

### Debug a failed HelmRelease

```bash
flux logs --kind=HelmRelease --name=<name> -n <ns>  # controller logs
flux get helmrelease <name> -n <ns>                  # status and last revision
helm history <name> -n <ns>                          # rollback candidates
kubectl describe helmrelease <name> -n <ns>          # events and conditions
```

### Image update automation

> Image Automation APIs are GA at `image.toolkit.fluxcd.io/v1` since Flux 2.7.

```bash
# 1. ImageRepository (scan) -> 2. ImagePolicy (semver filter)
# 3. Mark manifests with `# {"$imagepolicy": "ns:policy"}`
# 4. ImageUpdateAutomation commits changes back to Git
flux get images all -A
```

> Flux supports `OCIRepository` sources as an alternative to Git for OCI-stored configs.

## Patterns We Use

| Choice | Over | Why |
|---|---|---|
| **FluxCD** | ArgoCD | Lightweight, pure K8s CRDs, composable with Kustomize |
| **SOPS + age** | Sealed Secrets / Vault | Encrypted secrets in Git; age keys simple; no extra controller |
| **Gateway API + Envoy Gateway** | ingress-nginx (retired March 2026) | Future-proof K8s-native routing, role-based config, expressive L7 features |
| **MetalLB** | cloud LB | Bare-metal L2/BGP advertisement for LoadBalancer Services |
| **KubeVirt** | separate hypervisor | VM workloads alongside containers on the same cluster |
| **Nix flake dev shell** | manual tool install | `nix develop` pins kubectl, helm, flux, sops, age, just |

> cert-manager works with Gateway API via native `gateway.networking.k8s.io` integration.

## Anti-Patterns
- **`kubectl apply` from laptops in prod** -- bypasses Git, creates invisible drift
- **Mutable image tags** (`:latest`) -- use image automation or pinned digests
- **Plaintext secrets in Git** -- always SOPS-encrypt; if committed plain, rotate immediately
- **Missing resource requests/limits** -- noisy neighbors and OOM kills
- **cluster-admin RBAC for apps** -- scope to minimum namespace and verbs
- **Manual drift fixes without updating Git** -- the controller will revert; change Git
- **Skipping health checks** -- pods get traffic before ready

Refs: [FluxCD](https://fluxcd.io/flux/) | [Kubernetes](https://kubernetes.io/docs/) | [OpenGitOps](https://opengitops.dev/) | [Flux SOPS](https://fluxcd.io/flux/guides/mozilla-sops/)
