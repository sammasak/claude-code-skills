---
name: kubernetes-gitops
description: "Use when working with Kubernetes clusters, GitOps deployments, Flux reconciliation, Helm releases, or cluster troubleshooting. Guides declarative cluster management and GitOps workflows. Not for secrets encryption or SOPS operations — route those to secrets-management."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Kubernetes GitOps

Manage Kubernetes clusters declaratively through Git-driven reconciliation loops.

**CRITICAL: Never push changes directly to the cluster from a workstation.** All changes must go through Git — direct `kubectl apply` creates invisible drift the controller will fight against.

**IMPORTANT: Always run `flux diff kustomization <name>` before reconciling.** Preview changes to avoid accidentally applying destructive patches.

**NOTE:** Flux v2.7+ supports global SOPS decryption via `--sops-age-secret` controller flag.

## Principles

- **Git is the single source of truth** — desired state lives in version control
- **Pull-based reconciliation** — the cluster pulls from Git; CI never pushes
- **Drift detection** — controllers converge actual toward declared state
- **Declarative desired state** — describe *what*, never script *how*

## Repository Structure

```
clusters/<cluster>/flux-system/        # Flux entrypoint
clusters/<cluster>/infrastructure.yaml # ordering: infra before apps
apps/base/                             # Kustomize bases
apps/overlays/{staging,production}/    # env-specific patches
infrastructure/controllers/            # shared infra
```

### Kustomization Layering

| Layer | Purpose |
|---|---|
| `base/` | App defaults, common labels, base manifests |
| `overlays/<env>/` | Env-specific patches, replicas, limits |
| `clusters/<name>/` | Cluster bindings, Flux orchestration |

### HelmRelease (key fields)

```yaml
spec:
  interval: 30m
  chart:
    spec:
      version: "1.x"                  # semver range
  valuesFrom:
    - kind: ConfigMap                 # values in Git, not inline
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      remediateLastFailure: true
  driftDetection:
    mode: enabled
```

### Workload Requirements

- [ ] `resources.requests` and `resources.limits` on every container
- [ ] `readinessProbe` and `livenessProbe` on every Deployment
- [ ] Namespace Pod Security Standard label (`restricted` or `baseline`)
- [ ] Per-workload ServiceAccount; NetworkPolicy restricting ingress/egress

## Workflow

```bash
# Health check
flux check && kubectl get nodes -o wide
flux get all -A && flux logs --all-namespaces --level=error

# Force reconciliation
flux diff kustomization <name>
flux reconcile source git flux-system
flux reconcile kustomization flux-system --with-source

# Debug failed HelmRelease
flux logs --kind=HelmRelease --name=<name> -n <ns>
helm history <name> -n <ns>
kubectl describe helmrelease <name> -n <ns>

# Rollback
sudo nixos-rebuild switch --rollback    # NixOS hosts
helm rollback <name> <revision> -n <ns> # Helm releases
```

## Patterns We Use

| Choice | Over | Why |
|---|---|---|
| **FluxCD** | ArgoCD | Lightweight, pure K8s CRDs, composable with Kustomize |
| **SOPS + age** | Sealed Secrets / Vault | Encrypted in Git; no extra controller |
| **Gateway API + Envoy Gateway** | ingress-nginx (retired) | K8s-native routing, L7 features |
| **MetalLB** | cloud LB | Bare-metal L2/BGP for LoadBalancer Services |
| **KubeVirt** | separate hypervisor | VMs alongside containers on same cluster |

## Anti-Patterns

- **Do not claim rollout succeeded because `kubectl apply` exited 0.** Run `kubectl rollout status` — apply only submits desired state
- **`kubectl apply` from laptops in prod** — bypasses Git, creates invisible drift
- **Mutable image tags** (`:latest`) — use image automation or pinned digests
- **Plaintext secrets in Git** — always SOPS-encrypt; if committed plain, rotate immediately
- **Missing resource requests/limits** — noisy neighbors and OOM kills
- **Manual drift fixes without updating Git** — the controller will revert
