# Review: kubernetes-gitops + k8s-debugger

## Score: 7/10

Both files demonstrate strong foundational knowledge of Kubernetes GitOps patterns and are well-structured. However, there are several issues ranging from a significant upcoming deprecation not addressed (ingress-nginx retirement) to minor inaccuracies and missing modern patterns that prevent a higher score.

---

## Findings

### Accurate

**kubernetes-gitops (SKILL.md)**

- **GitOps principles section** is well-aligned with the OpenGitOps 1.0 principles (declarative, versioned/immutable, pull-based, continuous reconciliation). The wording maps cleanly to the CNCF OpenGitOps specification.
- **Repository structure** follows the canonical FluxCD multi-cluster layout from the official `flux2-kustomize-helm-example` repository. The `clusters/`, `infrastructure/`, `apps/` separation with Kustomize layering is the recommended pattern.
- **HelmRelease API version** (`helm.toolkit.fluxcd.io/v2`) is correct. This is the current stable API as of Flux 2.6+ and remains stable in Flux 2.7.5 (latest as of February 2026).
- **HelmRelease pattern** is solid: semver range for chart version, `valuesFrom` pointing to a ConfigMap (values in Git, not inline), and install/upgrade remediation with retries are all best practices.
- **`remediateLastFailure: true`** under `spec.upgrade.remediation` is valid and still supported in the `helm.toolkit.fluxcd.io/v2` API. This field was not removed or deprecated.
- **Kustomization layering table** (base/overlays/clusters) is accurate and reflects real-world FluxCD usage.
- **Pod Security Standard namespace labels** (`enforce: restricted` or `baseline`) is correct. PodSecurityPolicy (PSP) was removed in Kubernetes 1.25; Pod Security Admission (PSA) with namespace-level labels is the replacement, and the skill correctly references it.
- **Workload requirements checklist** is complete and appropriate: resource requests/limits, probes, PSS labels, dedicated ServiceAccounts, NetworkPolicy.
- **Flux CLI commands** (`flux get all -A`, `flux get sources all -A`, `flux reconcile source git`, `flux reconcile kustomization`, `flux reconcile helmrelease`, `flux logs --kind=HelmRelease`) all use valid current syntax.
- **SOPS + age recommendation** is still the recommended approach for secret encryption in Git with FluxCD. The official Flux SOPS guide (last updated June 2025) continues to recommend age over OpenPGP.
- **Image update automation** description is accurate: ImageRepository, ImagePolicy, `$imagepolicy` marker comments, and ImageUpdateAutomation are the correct resources and workflow. The marker comment syntax `# {"$imagepolicy": "ns:policy"}` is correct.
- **Anti-patterns section** is excellent and all items remain valid: no kubectl apply from laptops, no mutable tags, no plaintext secrets, no missing resource requests/limits, no cluster-admin RBAC, no manual drift fixes, no skipping health checks.

**k8s-debugger (agent file)**

- **Top-down diagnostic methodology** (cluster -> system -> GitOps -> workload -> deep dive) is a sound debugging approach.
- **Common patterns table** is accurate: CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled, Evicted, and Flux reconciliation failure are all correctly mapped to likely causes and first commands.
- **`kubectl logs <pod> --previous`** for CrashLoopBackOff is the correct approach to get logs from the crashed container.
- **`flux logs --level=error`** syntax is valid. The `--level` flag accepts `debug`, `info`, or `error`.
- **Blast radius prioritization** (nodes > system pods > platform services > application pods) is a pragmatic and correct triage order.
- **Rules about gathering evidence before assuming** and showing exact commands are good agent instructions.

---

### Issues

#### Issue 1: ingress-nginx Retirement Not Addressed (Critical)

**File:** `skills/kubernetes-gitops/SKILL.md`, line 128

**What it says:**
> `ingress-nginx + cert-manager` over `Traefik / manual certs` -- "DNS-01 challenge via Cloudflare; wildcard certs; battle-tested"

**Problem:** The Kubernetes project officially announced the retirement of ingress-nginx, with end-of-life in **March 2026** (one month from now as of this review). After that date, there will be no further releases, no bug fixes, and no security patches. The recommended migration path is to the **Kubernetes Gateway API** with implementations such as Envoy Gateway, NGINX Gateway Fabric, Contour, or Istio.

Recommending ingress-nginx as a pattern choice in early 2026 without any caveat about its imminent retirement is misleading and could lead teams to adopt infrastructure that will be unsupported within weeks.

**What it should say:** The "Patterns We Use" table should either:
1. Replace the ingress-nginx recommendation with Gateway API + a specific implementation (e.g., Envoy Gateway, NGINX Gateway Fabric), or
2. Add a prominent note that ingress-nginx reaches end-of-life March 2026 and document the migration plan.

**Source:** [Ingress NGINX Retirement: What You Need to Know | Kubernetes Blog](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)

---

#### Issue 2: Missing `flux logs --all-namespaces` Flag in Health Check Commands

**File:** `skills/kubernetes-gitops/SKILL.md`, line 88-92

**What it says:**
```bash
flux get all -A                                     # reconciliation status across all objects
flux get sources all -A                             # source freshness
```

These correctly use `-A`, but earlier the "Debug a failed HelmRelease" section (lines 105-109) is namespace-scoped which is appropriate. However, the cluster health check section does not include `flux logs --all-namespaces --level=error` as a quick error scan, which would be a valuable addition alongside the existing commands.

**Severity:** Minor (not incorrect, just incomplete for a health check section).

---

#### Issue 3: Missing `flux migrate` Awareness for API Version Transitions

**File:** `skills/kubernetes-gitops/SKILL.md`

**What it says:** The file uses `helm.toolkit.fluxcd.io/v2` which is correct, but provides no guidance on API migration.

**Problem:** As of Flux v2.7, the v1beta1/v2beta1 APIs have been removed. In Flux v2.8 (planned Q1 2026 -- imminent), the v1beta2/v2beta2 APIs will also be removed. Teams upgrading Flux must run `flux migrate -v 2.6 -f .` before upgrading to v2.7+. This is a critical operational concern that a GitOps skill should mention.

**What it should include:** A note in the Workflow section about running `flux migrate` before Flux upgrades, and the importance of using stable API versions (v1 for source/kustomize/image, v2 for helm).

**Source:** [Upgrade Procedure for Flux v2.7+](https://github.com/fluxcd/flux2/discussions/5572)

---

#### Issue 4: Image Automation API Version Not Specified

**File:** `skills/kubernetes-gitops/SKILL.md`, lines 114-119

**What it says:** The image automation section describes the workflow in comments but does not show actual YAML manifests or specify the API version.

**Problem:** As of Flux v2.7, the Image Automation APIs have been promoted to GA with `image.toolkit.fluxcd.io/v1`. Previously they were at `v1beta1` and `v1beta2`. The skill should specify that ImageRepository, ImagePolicy, and ImageUpdateAutomation now use `image.toolkit.fluxcd.io/v1`.

**Source:** [Announcing Flux 2.7 GA](https://fluxcd.io/blog/2025/09/flux-v2.7.0/)

---

#### Issue 5: Agent `model` Field Uses Specific Model Name Instead of Alias

**File:** `agents/k8s-debugger.md`, line 5

**What it says:**
```yaml
model: haiku
```

**Assessment:** This is actually correct per current Claude Code conventions. The model field accepts aliases (`sonnet`, `opus`, `haiku`) or `inherit`. Using `haiku` is valid and appropriate for a lightweight debugging agent that primarily runs kubectl commands and parses output. No change needed.

---

#### Issue 6: Agent `tools` Field Format

**File:** `agents/k8s-debugger.md`, line 6

**What it says:**
```yaml
tools: Bash, Read, Grep, Glob
```

**Assessment:** The Claude Code agent format supports both comma-separated strings and YAML arrays (`[Bash, Read, Grep, Glob]`). The comma-separated format works. However, the tool names should be lowercase per the latest documented conventions (e.g., `bash`, `read`, `grep`, `glob` rather than capitalized). The official examples in the Claude Code documentation use lowercase tool names in agent files.

**What it should say:**
```yaml
tools: [bash, read, grep, glob]
```

**Source:** [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)

---

#### Issue 7: Skill `allowed-tools` Field Format

**File:** `skills/kubernetes-gitops/SKILL.md`, line 4

**What it says:**
```yaml
allowed-tools: Bash Read Grep Glob
```

**Assessment:** The skill frontmatter uses space-separated tool names. Official examples show comma-separated format: `allowed-tools: Bash, Read, Grep`. The space-separated format may work but does not match the documented convention.

**What it should say:**
```yaml
allowed-tools: Bash, Read, Grep, Glob
```

**Source:** [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)

---

#### Issue 8: cgroup v1 Deprecation Not Mentioned

**File:** `skills/kubernetes-gitops/SKILL.md`

**Problem:** Kubernetes 1.35 (December 2025) deprecated cgroup v1 support. The kubelet will refuse to start by default on nodes using cgroup v1. For bare-metal clusters (which this skill references with MetalLB), this is operationally significant and could cause node failures during upgrades.

**Severity:** Minor -- more of a missing item than an inaccuracy.

**Source:** [Kubernetes v1.35 Release Blog](https://kubernetes.io/blog/2025/12/17/kubernetes-v1-35-release/)

---

### Missing

1. **Gateway API migration guidance.** With ingress-nginx retiring in March 2026 and Gateway API at v1.4 (GA since v1.0 in October 2023), the skill should include Gateway API as a pattern, or at minimum reference it as the future direction for service networking.

2. **Flux v2.7+ new features.** Several significant features are not mentioned:
   - `reconcile.fluxcd.io/watch: Enabled` label for ConfigMap/Secret watching (triggers immediate reconciliation on referenced resource changes)
   - ExternalArtifact and ArtifactGenerator CRDs for source composition
   - Drift detection configuration in HelmRelease (`spec.driftDetection`)
   - CEL expressions for dependency readiness (`spec.dependsOn[].readyExpr`)

3. **OCI sources.** The skill only mentions Git-based sources, but Flux has full GA support for OCI repositories (`OCIRepository`) as artifact sources. Many teams now distribute Kubernetes manifests and Helm charts via OCI registries.

4. **In-Place Pod Resize.** Kubernetes 1.35 graduated In-Place Pod Resize to stable. This is relevant to the workload requirements checklist, as it changes how resource limits can be managed without pod restarts.

5. **`flux check` command.** The health check workflow does not mention `flux check` which validates the Flux installation and reports version information. This is a standard first step in troubleshooting.

6. **`flux diff` command.** Not mentioned but useful for previewing what a reconciliation would change before it happens.

7. **Agent missing RBAC troubleshooting guidance.** The k8s-debugger agent covers pod-level issues well but does not include RBAC-related debugging patterns (e.g., `kubectl auth can-i`, `kubectl auth whoami`), which is a common source of deployment failures.

8. **Agent missing certificate/TLS troubleshooting.** Given that cert-manager is listed as part of the infrastructure stack, the debugger agent should include patterns for diagnosing certificate issuance failures (`kubectl describe certificate`, `kubectl describe certificaterequest`, `cmctl status certificate`).

---

### References Check

| Reference | Status | Notes |
|---|---|---|
| [FluxCD documentation](https://fluxcd.io/flux/) | **VALID** | Active, last modified 2025-03-14. Current version is v2.7. |
| [Kubernetes official docs](https://kubernetes.io/docs/) | **VALID** | Active, Kubernetes 1.35 is latest. |
| [OpenGitOps principles](https://opengitops.dev/) | **VALID** | Active CNCF Sandbox project, last updated January 2026. |
| [GitOps and Kubernetes](https://www.manning.com/books/gitops-and-kubernetes) (Manning) | **UNVERIFIABLE** | Manning website returned a connection error during fetch. The book was published in 2022 by Billy Yuen et al. It may still be available but the content is aging (covers Flux v2 beta-era APIs). Consider supplementing with the official Flux documentation as primary reference. |
| [Flux SOPS integration guide](https://fluxcd.io/flux/guides/mozilla-sops/) | **VALID** | Active, last modified 2025-06-13. Covers age, OpenPGP, and cloud KMS. |

---

### Recommendations

#### Priority 1 (Critical -- address before March 2026)

1. **Update the ingress-nginx recommendation.** Either replace with Gateway API + an implementation, or add a deprecation notice. Example replacement row:

   | **Gateway API + Envoy Gateway** | ingress-nginx (retired March 2026) | Future-proof, role-based routing, native K8s standard, expressive L7 features |

2. **Add a note about cert-manager compatibility.** cert-manager works with Gateway API via the `gateway.networking.k8s.io/v1` resources, so the cert-manager recommendation remains valid regardless of the ingress controller change.

#### Priority 2 (Important -- address in next revision)

3. **Add `flux check` to the cluster health check workflow** as the first command in the sequence.

4. **Add a Flux API migration note** to the Workflow section:
   ```bash
   # Before upgrading Flux, migrate manifests to stable APIs
   flux migrate -v 2.6 -f .
   ```

5. **Specify image automation API version** as `image.toolkit.fluxcd.io/v1` (GA since Flux 2.7).

6. **Fix agent `tools` field** to use lowercase tool names in array format: `tools: [bash, read, grep, glob]`.

7. **Fix skill `allowed-tools` field** to use comma-separated format: `allowed-tools: Bash, Read, Grep, Glob` (currently uses space-separated).

#### Priority 3 (Nice to have)

8. **Add OCI repository pattern** as an alternative to Git-based sources for Helm charts and manifests.

9. **Add drift detection configuration** to the HelmRelease pattern example:
   ```yaml
   driftDetection:
     mode: enabled
   ```

10. **Add RBAC and certificate debugging patterns** to the k8s-debugger agent (e.g., `kubectl auth can-i`, `cmctl status certificate`).

11. **Add `flux diff kustomization`** to the workflow for previewing changes before reconciliation.

12. **Consider mentioning the `reconcile.fluxcd.io/watch: Enabled` label** for ConfigMaps/Secrets referenced in HelmReleases and Kustomizations (new in Flux 2.7).

13. **Consider adding `kubectl top` to the agent's initial cluster overview step** for immediate resource pressure visibility.

---

## Summary

The skill and agent files are fundamentally sound and demonstrate real operational knowledge. The GitOps principles, FluxCD patterns, SOPS integration, and debugging methodology are all correct. The most significant issue is the ingress-nginx recommendation, which will become actively harmful advice after March 2026. The remaining issues are a mix of missing modern features (Flux 2.7 GA capabilities, Gateway API) and minor formatting concerns. With the recommended changes, particularly around ingress-nginx and Flux API migration, these files would score 9/10.

---

*Review conducted: 2026-02-18*
*Kubernetes latest: v1.35.1 | FluxCD latest: v2.7.5 | Gateway API latest: v1.4.1*

### Sources consulted
- [Kubernetes v1.35 Release Blog](https://kubernetes.io/blog/2025/12/17/kubernetes-v1-35-release/)
- [Kubernetes Releases](https://kubernetes.io/releases/)
- [Ingress NGINX Retirement Announcement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
- [Gateway API v1.4 Release](https://kubernetes.io/blog/2025/11/06/gateway-api-v1-4/)
- [FluxCD Helm API v2 Reference](https://fluxcd.io/flux/components/helm/api/v2/)
- [Announcing Flux 2.7 GA](https://fluxcd.io/blog/2025/09/flux-v2.7.0/)
- [Flux Source API v1 Reference](https://fluxcd.io/flux/components/source/api/v1/)
- [Flux Kustomize API v1 Reference](https://fluxcd.io/flux/components/kustomize/api/v1/)
- [Flux Image Update Automation Guide](https://fluxcd.io/flux/guides/image-update/)
- [Flux SOPS Integration Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
- [Flux CLI Reference](https://fluxcd.io/flux/cmd/)
- [Flux Upgrade Procedure for v2.7+](https://github.com/fluxcd/flux2/discussions/5572)
- [Flux Roadmap](https://fluxcd.io/roadmap/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [OpenGitOps Principles](https://opengitops.dev/)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
