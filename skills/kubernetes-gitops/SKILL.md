---
name: kubernetes-gitops
description: "Use when changing or debugging anything in the homelab k3s cluster: manifests, Flux Kustomizations, HelmReleases, ingress, scaling, or node problems. Not for SOPS encryption (secrets-management) or confirming a finished deploy is live (verify-service)."
allowed-tools: Bash, Read, Grep, Glob
---

# Kubernetes GitOps (homelab)

`~/homelab-gitops` (Flux, pushes to `main`) is the source of truth and its `CLAUDE.md` is the detailed reference. Change the cluster through Git; a manual `kubectl apply` gets reverted by Flux.

## Topology

| Node | Role |
|---|---|
| `acer-swift` | the only always-on worker; every app pod runs here, so losing it is a total app outage |
| `lenovo-21cb001pmx` | control-plane, tainted; hosts ntfy, Tailscale subnet router, AdGuard DNS |
| `msi-ms7758` | intermittent opt-in worker, taint `sammasak.dev/intermittent=true:NoSchedule`; scheduled power window Mon-Fri ~09:00-21:00 (WoL from lenovo), otherwise off; never WoL it at night |

Platform: Flux, Cilium (CNI + kube-proxy replacement), MetalLB (pool 192.168.10.202-204), Traefik v3 on .203 (`*.sammasak.dev`), cert-manager (`letsencrypt-prod`, Cloudflare DNS-01), Authentik, KEDA + HTTP add-on, Kyverno, zot. Gone (do not reintroduce without an ADR): ingress-nginx, Harbor, Falco, Tempo, Pushgateway, Cloudflare tunnel, VM workloads.

## Conventions

- New app: `cp -r apps/_template apps/<app>`, then add `<app>/` to `apps/kustomization.yaml` (forgetting this deploys nothing, silently). Full walkthrough: `docs/adding-an-app.md`.
- Validate before pushing: `./scripts/validate.sh` (or `just validate`).
- `chat` and `llm` are separate Flux Kustomizations so slow model pulls cannot block `apps`.
- Ingress: `ingressClassName: traefik`, `traefik.ingress.kubernetes.io/*` annotations, `router.tls: "true"`, `cert-manager.io/cluster-issuer: letsencrypt-prod`. Authentik-gated apps add `traefik.ingress.kubernetes.io/router.middlewares: "authentik-authentik-forward-auth@kubernetescrd"`. ntfy is deliberately un-gated.
- Resources: CPU/memory requests and a memory limit; CPU limits are optional and usually wrong. Namespace PSS: `enforce: baseline`, `warn`/`audit: restricted`.
- Images by `@sha256:` digest from `registry.sammasak.dev/lab/`.

## Scale-to-zero traps

- HTTP apps sit at zero replicas behind the KEDA HTTP interceptor. Zero pods when idle is expected; check the `HTTPScaledObject` before calling it an incident.
- A single failing check after idle is usually a cold start; retry once before declaring an outage.
- If the KEDA interceptor is down, every scaled app 502s at once.

## Debug entry points

```bash
flux get kustomizations && flux get helmreleases -A
flux logs --all-namespaces --level=error
flux reconcile kustomization apps --with-source
just unhealthy        # in ~/homelab-gitops
```

For deeper diagnosis dispatch the `k8s-debugger` agent.
