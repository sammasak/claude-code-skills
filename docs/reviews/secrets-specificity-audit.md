# Secrets Management -- Specificity Audit

Audit of `/skills/secrets-management/SKILL.md` for user-specific or oddly specific content that limits reusability.

---

## Finding 1: Environment names hardcoded to a three-tier model

**Lines:** 36-41 (`.sops.yaml` example), 29, 104

**Exact text (lines 36-41):**
```yaml
  - path_regex: clusters/prod/.*\.secret\.yaml$
    age: age1prod...  # prod recipient
  - path_regex: clusters/staging/.*\.secret\.yaml$
    age: age1staging...  # staging recipient
  - path_regex: clusters/dev/.*\.secret\.yaml$
    age: age1dev...  # dev recipient
```

**Line 29:**
```
| Separate keys per environment | Dev key cannot decrypt prod |
```

**Line 104:**
```
- **Separate age identity per environment** -- dev, staging, prod each hold their own key; compromise is isolated
```

**Assessment:** Mildly specific but reasonable. The `dev/staging/prod` trio is conventional enough to serve as an example. The path structure `clusters/<env>/` assumes a particular directory layout (matching the kubernetes-gitops skill's conventions), but this is clearly marked as an example. The principle (separate keys per environment) is universal.

**Verdict:** Acceptable as-is. The example illustrates the pattern without forcing adoption of those exact names.

---

## Finding 2: `age` prescribed as the sole encryption backend

**Lines:** 37-41, 64-68, 101, 104

**Exact text (line 101):**
```
- **age over PGP** -- simpler key management, no key servers, no expiry headaches. age v1.3+ adds post-quantum hybrid keys (`age1pq1...`; cannot mix with classic `age1...` recipients); SOPS does not yet support PQ keys
```

**Assessment:** The skill treats `age` as the default and only worked example. SOPS supports AWS KMS, GCP KMS, Azure Key Vault, and HashiCorp Vault transit as key sources. The References section on line 126 does mention these alternatives in passing ("supporting age, AWS KMS, GCP KMS, Azure Key Vault"), but the Standards table (line 24) says "SOPS for file-level encryption" without acknowledging that some teams use cloud KMS directly without SOPS, and the workflow section exclusively demonstrates `age-keygen`.

**Verdict:** Mildly user-specific. The `age` preference is a deliberate opinionated choice, which is fine for a skill, but the document would be more honest if the Standards table or Patterns section included a one-liner like: "For cloud-managed keys, SOPS also works with AWS KMS, GCP KMS, and Azure Key Vault -- no age keypair needed."

**Suggested fix:** Add a brief note to the Workflow section acknowledging alternative key backends:
```
> Note: This workflow uses age keys. If your infrastructure uses AWS KMS, GCP KMS,
> or Azure Key Vault, replace the age recipient in `.sops.yaml` with the appropriate
> KMS ARN / resource ID. The encrypt/decrypt commands remain the same.
```

---

## Finding 3: Flux assumed as the sole deployment mechanism

**Lines:** 76, 102-103, 108

**Exact text (line 76):**
```
6. **Deploy** -- Flux SOPS kustomize-controller decrypts at apply time
```

**Line 102-103:**
```
- **SOPS for all GitOps secrets** -- works with Flux natively, encrypted files live alongside manifests
- **Flux kustomize-controller** with SOPS decryption provider -- secrets decrypted only at deploy time in-cluster
```

**Line 108:**
```
- **Flux v2.7+** global SOPS decryption -- `--sops-age-secret` controller flag eliminates per-Kustomization decryption config
```

**Assessment:** Flux is named as the only GitOps controller. ArgoCD (with the KSOPS plugin or argocd-vault-plugin) is a widely-used alternative. The document reads as though Flux is the universal choice rather than this team's choice.

**Verdict:** User-specific. The Flux details (especially the v2.7+ flag on line 108) are infrastructure-specific configuration that only applies to Flux users.

**Suggested fix:** Reframe the deploy step and patterns to be GitOps-generic with Flux as the primary example:
- Line 76: `6. **Deploy** -- GitOps controller decrypts at apply time (e.g., Flux kustomize-controller with SOPS provider, or ArgoCD with KSOPS plugin)`
- Line 102: Add a parenthetical or note: "ArgoCD users can integrate SOPS via the KSOPS plugin."
- Line 108: Prefix with "If using Flux:" to make it clear this is Flux-specific guidance.

---

## Finding 4: `clusters/` path convention assumed in `.sops.yaml`

**Lines:** 36-41

**Exact text:**
```yaml
  - path_regex: clusters/prod/.*\.secret\.yaml$
  - path_regex: clusters/staging/.*\.secret\.yaml$
  - path_regex: clusters/dev/.*\.secret\.yaml$
```

**Assessment:** The `clusters/<env>/` directory structure is a specific convention (matching the kubernetes-gitops skill). Many teams use `environments/`, `deploy/`, `infra/`, or flat structures. Since this is in an example block, it is less concerning, but a reader might copy it verbatim.

**Verdict:** Borderline. Acceptable as an example, but would benefit from a comment noting the path is illustrative.

**Suggested fix:** Add a YAML comment:
```yaml
creation_rules:
  # Adjust path_regex patterns to match your repository layout
  - path_regex: clusters/prod/.*\.secret\.yaml$
```

---

## Finding 5: `cert-manager` stated as a pattern without alternatives

**Line:** 106

**Exact text:**
```
- **cert-manager** for TLS certificates -- automated issuance and renewal, no manual cert management
```

**Assessment:** cert-manager is the dominant Kubernetes TLS solution and this is a reasonable recommendation. However, it is stated as "Patterns We Use" -- the "We" framing throughout this section (line 99: "Patterns We Use") is inherently user-specific. It describes one team's stack rather than universal best practices.

**Verdict:** The section header "Patterns We Use" is explicitly personal/team-specific by design, so cert-manager fits that framing. No change needed for cert-manager specifically, but see Finding 7 about the section header.

---

## Finding 6: Specific SOPS version detail for Flux

**Line:** 108

**Exact text:**
```
- **Flux v2.7+** global SOPS decryption -- `--sops-age-secret` controller flag eliminates per-Kustomization decryption config
```

**Assessment:** This is a very specific piece of operational knowledge tied to a particular Flux version and a specific controller flag. It is useful for Flux users but meaningless (and potentially confusing) for anyone else.

**Verdict:** User-specific. This is operational tribal knowledge for a Flux-based setup.

**Suggested fix:** Move to a "Flux-specific notes" subsection or inline it with a qualifier: "If using Flux v2.7+: the `--sops-age-secret` controller flag..."

---

## Finding 7: "Patterns We Use" section header

**Line:** 99

**Exact text:**
```
## Patterns We Use
```

**Assessment:** The "We Use" framing is intentionally opinionated, but it creates a first-person voice that presumes the reader shares the same infrastructure. Every item in this section (age, SOPS, Flux, cert-manager, ESO) represents a specific stack.

**Verdict:** This is a style/design choice rather than a bug. If the skill is meant to be shareable beyond the original team, consider renaming to "Recommended Patterns" or "Patterns" with a note that these reflect a specific opinionated stack. If it is intentionally a team playbook, the "We Use" framing is fine.

---

## Summary

| # | Line(s) | Item | Severity | Action |
|---|---------|------|----------|--------|
| 1 | 36-41, 29, 104 | dev/staging/prod environment names | Low | Acceptable as example |
| 2 | 37-41, 64-68, 101, 104 | age as sole key backend | Medium | Add note about cloud KMS alternatives |
| 3 | 76, 102-103, 108 | Flux as sole GitOps controller | Medium | Mention ArgoCD/KSOPS as alternative |
| 4 | 36-41 | `clusters/` path convention | Low | Add comment that paths are illustrative |
| 5 | 106 | cert-manager without alternatives | Low | Acceptable under "Patterns We Use" |
| 6 | 108 | Flux v2.7+ specific flag | Medium | Qualify as Flux-specific |
| 7 | 99 | "Patterns We Use" header | Low | Consider "Recommended Patterns" if sharing broadly |

**Overall assessment:** The skill is well-structured and the core principles (lines 12-18) and anti-patterns (lines 112-122) are fully generic and universally applicable. The specificity concentrations are in the Workflow section (Flux-centric deploy step) and the Patterns section (age + Flux + cert-manager stack). The most actionable fixes are Findings 2, 3, and 6 -- adding brief acknowledgment of alternative key backends and GitOps controllers so the skill reads as "opinionated default" rather than "only option."
