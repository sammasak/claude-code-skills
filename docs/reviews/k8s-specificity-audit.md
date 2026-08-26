# Kubernetes / GitOps Specificity Audit

Reviewing `skills/kubernetes-gitops/SKILL.md` and `agents/k8s-debugger.md` for
user-specific content that should be genericised or flagged as opinionated.

---

## skills/kubernetes-gitops/SKILL.md

### Finding 1 -- "Patterns We Use" heading and opinionated tool table

**Lines:** 128-137
**Text:**
```
## Patterns We Use

| Choice | Over | Why |
|---|---|---|
| **FluxCD** | ArgoCD | Lightweight, pure K8s CRDs, composable with Kustomize |
| **SOPS + age** | Sealed Secrets / Vault | Encrypted secrets in Git; age keys simple; no extra controller |
| **Gateway API + Envoy Gateway** | ingress-nginx (retired March 2026) | Future-proof K8s-native routing, role-based config, expressive L7 features |
| **MetalLB** | cloud LB | Bare-metal L2/BGP advertisement for LoadBalancer Services |
| **KubeVirt** | separate hypervisor | VM workloads alongside containers on the same cluster |
| **Nix flake dev shell** | manual tool install | `nix develop` pins kubectl, helm, flux, sops, age, just |
```
**Verdict:** User-specific. This entire section encodes one person's homelab/bare-metal
stack as if it were universal GitOps guidance. Specific issues:

- **FluxCD over ArgoCD** -- reasonable opinion but stated as a blanket standard.
  A generic skill should present FluxCD patterns without dismissing ArgoCD.
- **MetalLB** -- reveals this is for a bare-metal / homelab cluster. Cloud users
  would never choose MetalLB. Should be qualified as "bare-metal only".
- **KubeVirt** -- very niche. Running VMs on Kubernetes is an unusual workload
  pattern specific to this user's setup (likely consolidating a hypervisor onto
  a k8s cluster). Not relevant to general GitOps guidance.
- **Nix flake dev shell** -- cross-references another personal skill. A generic
  skill should say "pin tool versions via a reproducible method (Nix, asdf,
  mise, devbox, etc.)".
- **Gateway API + Envoy Gateway** -- the "ingress-nginx (retired March 2026)"
  note is a useful fact but "Envoy Gateway" is an opinionated selection; many
  users will choose Istio, Contour, or Cilium Gateway API implementations.

**Suggested fix:** Rename section to "Opinionated Defaults" or "Example Stack" to
frame it as one valid configuration. Better yet, remove the versus table and
instead provide guidance like "choose a GitOps controller (Flux, ArgoCD, ...)"
with links. Move bare-metal-specific items (MetalLB, KubeVirt) to a separate
"Bare-Metal Considerations" subsection. Remove the Nix flake row entirely (it
is covered by the separate nix-flake-development skill and is not Kubernetes
specific).

---

### Finding 2 -- Entire file is Flux-only

**Lines:** 1-150 (whole file)
**Text:** The skill name is "kubernetes-gitops" but every workflow command, every
pattern, every example is Flux-specific (`flux check`, `flux reconcile`,
`flux get`, `flux logs`, `flux diff`, `flux migrate`, HelmRelease CRDs from
`helm.toolkit.fluxcd.io`).

**Verdict:** User-specific framing. The skill title implies generic GitOps but
delivers a Flux operations manual. An ArgoCD user would get no value from this.

**Suggested fix:** Either:
1. Rename to `flux-gitops` and state upfront that this skill assumes FluxCD, or
2. Keep the generic name but restructure: universal GitOps principles at the
   top (already present and good), then a clearly marked "Flux Implementation"
   section for the Flux-specific workflows.

---

### Finding 3 -- "ingress-nginx (retired March 2026)" claim

**Line:** 134
**Text:** `ingress-nginx (retired March 2026)`

**Verdict:** Potentially inaccurate or speculative. As of the knowledge cutoff,
ingress-nginx is maintained and widely deployed. The "retired March 2026"
claim may be based on a misread of the Ingress API deprecation timeline or a
specific vendor announcement. Presenting it as settled fact could mislead.

**Suggested fix:** Verify the retirement claim. If accurate, add a source link.
If not, soften to "ingress-nginx (legacy Ingress API; consider Gateway API
for new clusters)".

---

### Finding 4 -- Repository structure assumes Flux

**Lines:** 23-31
**Text:**
```
clusters/<cluster>/flux-system/        # Flux entrypoint per cluster
clusters/<cluster>/infrastructure.yaml # Kustomization ordering infra before apps
clusters/<cluster>/apps.yaml
infrastructure/controllers/            # Shared infra (ingress, cert-manager, etc.)
infrastructure/configs/                # Cluster-wide configs (PSS, network policies)
apps/base/                             # Kustomize bases per app
apps/overlays/{staging,production}/
```

**Verdict:** Reasonable as an opinionated example, but user-specific in that it is
the canonical Flux monorepo layout. Not universally applicable (ArgoCD app-of-apps,
Kargo pipelines, etc. look different).

**Suggested fix:** Label as "Example: Flux monorepo layout" rather than presenting
as the universal standard.

---

### Finding 5 -- "Nix develop" pinning referenced in table

**Line:** 137
**Text:** `` `nix develop` pins kubectl, helm, flux, sops, age, just ``

**Verdict:** User-specific. This reveals the user's exact toolset (including
`just` as a task runner and `age` as the SOPS backend). The Nix cross-reference
couples this skill to the user's development environment.

**Suggested fix:** Remove this row. Tool version pinning is out of scope for a
Kubernetes/GitOps skill.

---

### Finding 6 -- SOPS + age presented as the only secrets path

**Lines:** 133, 143-144
**Text:**
```
| **SOPS + age** | Sealed Secrets / Vault | Encrypted secrets in Git; age keys simple; no extra controller |
```
and:
```
- **Plaintext secrets in Git** -- always SOPS-encrypt; if committed plain, rotate immediately
```

**Verdict:** Mildly user-specific. SOPS+age is a legitimate choice but stating
"always SOPS-encrypt" as a blanket rule ignores equally valid patterns
(External Secrets Operator, Vault CSI, Sealed Secrets). Many production
environments use Vault or cloud KMS natively.

**Suggested fix:** Change anti-pattern to: "Plaintext secrets in Git -- always
encrypt (SOPS, Sealed Secrets) or use external secret backends; if committed
plain, rotate immediately."

---

## agents/k8s-debugger.md

### Finding 7 -- Flux-specific debugging in a generic K8s debugger

**Lines:** 3-4, 18, 30
**Text:**
```
Flux reconciliation errors
```
```
3. **GitOps state**: `flux get all -A`, `flux logs --level=error` for failures
```
```
| Flux failed | Bad values, dependency not ready, SOPS error | `flux logs --kind=HelmRelease --name=<name>` |
```

**Verdict:** User-specific in that it assumes the cluster runs Flux. A generic K8s
debugger agent should not hardcode one GitOps tool.

**Suggested fix:** Either:
1. Rename to "Flux K8s Debugger" and scope it explicitly, or
2. Generalize step 3 to "GitOps state: check your GitOps controller (Flux:
   `flux get all -A`; ArgoCD: `argocd app list`)" and add a note that the Flux
   examples assume Flux is installed.

---

### Finding 8 -- `cmctl` assumed installed

**Line:** 32
**Text:** `` `cmctl status certificate <name>` ``

**Verdict:** Mildly user-specific. `cmctl` is the cert-manager CLI and is not
installed by default on most clusters. Many users interact with cert-manager
purely through `kubectl describe certificate` and `kubectl get certificaterequest`.

**Suggested fix:** Mark as optional: "if cert-manager CLI is available:
`cmctl status certificate <name>`". The `kubectl describe certificate` command
already listed on the same line is the universal fallback.

---

## Summary

| # | File | Line(s) | Severity | Category |
|---|---|---|---|---|
| 1 | SKILL.md | 128-137 | **High** | Entire "Patterns We Use" table is personal stack |
| 2 | SKILL.md | 1-150 | **Medium** | Skill titled "kubernetes-gitops" but is Flux-only |
| 3 | SKILL.md | 134 | **Medium** | Unverified "ingress-nginx retired March 2026" claim |
| 4 | SKILL.md | 23-31 | **Low** | Repo structure is Flux-specific, not labeled as such |
| 5 | SKILL.md | 137 | **Medium** | Nix flake / `just` cross-reference is personal setup |
| 6 | SKILL.md | 133,143 | **Low** | SOPS+age presented as the only secrets approach |
| 7 | k8s-debugger.md | 3,18,30 | **Medium** | Flux hardcoded in generic K8s debugger |
| 8 | k8s-debugger.md | 32 | **Low** | `cmctl` assumed available without qualification |

### Overall Assessment

No hardcoded hostnames, IPs, usernames, emails, or registry URLs were found --
these files are clean on that front. The primary specificity issue is
**architectural**: the files encode a specific bare-metal Flux + SOPS + age +
MetalLB + KubeVirt + Nix stack as universal Kubernetes/GitOps guidance. The
biggest remediation win would be renaming or restructuring to make the Flux
dependency explicit and moving the "Patterns We Use" table into a clearly
scoped "opinionated defaults" frame.
