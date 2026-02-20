# Re-Review: secrets-management (Round 2)

## Previous Score: 7/10
## New Score: 9/10

The updated skill file addresses all four Issues from the original review and five of the seven Missing items. The fixes are technically accurate and well-integrated. Two lower-priority Missing items remain unaddressed, and no new issues were introduced. The file stays within the 150-line budget at 129 lines.

---

## Issues From Original Review

### Issue 1: Outdated SOPS CLI syntax -- FIXED

The skill now uses subcommand syntax throughout:

- `sops encrypt -i secret.yaml` (line 73)
- `sops decrypt secret.yaml` (line 85)
- `sops rotate -i secret.yaml` (line 80)
- `sops edit <file>` (quick-reference table, line 93)

The quick-reference table (lines 90-97) is fully updated to subcommand syntax. This matches the current SOPS README, which uses subcommands exclusively. Verified against the SOPS GitHub repository -- the README demonstrates `sops edit`, `sops decrypt`, and `sops encrypt` as the standard syntax.

**Verdict:** Fully resolved. No residual issues.

### Issue 2: Incorrect book reference -- FIXED

The incorrect `"Security Chaos Engineering" -- Kennedy, Nolan` reference has been removed entirely and replaced with `[Kubernetes Secrets good practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)` (line 129). This was one of the two acceptable options suggested in the original review.

The replacement URL is verified live (last modified June 22, 2025) and covers encryption at rest, RBAC for Secrets, etcd management, and external secrets -- all directly relevant to this skill's scope. This is arguably a better reference than the original book since it is freely available, authoritative, and more directly on-topic.

**Verdict:** Fully resolved. Replacement reference is a strong choice.

### Issue 3: Incomplete key rotation workflow -- FIXED

The Workflow step 7 (lines 77-82) now shows both operations:

```bash
sops updatekeys secret.yaml          # sync recipients from .sops.yaml
sops rotate -i secret.yaml           # rotate data encryption key
```

The explanatory note "Both steps are needed when removing a recipient" (line 82) correctly communicates the critical security point: after removing a recipient, the data encryption key must be rotated so the removed party cannot use a previously-obtained data key.

**Verdict:** Fully resolved. The fix is technically accurate and clearly explained.

### Issue 4: Quick-reference table disagrees with workflow -- FIXED

The quick-reference table (lines 90-97) lists both `sops rotate -i <file>` and `sops updatekeys <file>` as separate entries, and the workflow (step 7) now shows both commands together with clear labels. The table and workflow are now consistent with each other. Both use the updated subcommand syntax.

**Verdict:** Fully resolved. No contradiction remains.

---

## Missing Items From Original Review

### Missing 1: No mention of External Secrets Operator (ESO) -- FIXED

Line 107 adds: `For vault-backed dynamic secrets, consider **External Secrets Operator (ESO)** as an alternative to encrypt-in-Git`

This is a concise, well-positioned mention that captures the key trade-off (encrypt-in-Git via SOPS vs. vault-backed dynamic secrets via ESO) without bloating the file.

**Verdict:** Adequately addressed for a skill file of this scope.

### Missing 2: No mention of age post-quantum support -- NOT FIXED

There is no mention of age v1.3.0+ post-quantum hybrid encryption (ML-KEM-768), `age1pq1...` recipients, or `age-keygen -pq`. Verified that age v1.3.1 (December 2025) includes this feature. SOPS does not yet support post-quantum age recipients, so this is informational only.

This remains a minor gap. A single line such as "age v1.3+ supports post-quantum hybrid keys (`age1pq1...`); SOPS support pending" would keep the skill forward-looking without adding noise.

**Severity:** Low. Post-quantum age keys are not yet usable in SOPS workflows, so omitting this does not lead to incorrect guidance.

### Missing 3: No mention of Flux v2.7 global SOPS decryption -- FIXED

Line 108 adds: `**Flux v2.7+** global SOPS decryption -- --sops-age-secret controller flag eliminates per-Kustomization decryption config`

This is accurate. The `--sops-age-secret` flag was introduced in kustomize-controller as part of Flux v2.7 GA (September/October 2025). Verified via the Flux v2.7 announcement blog and kustomize-controller issue #1465. The description correctly explains the benefit: removing the need for `.spec.decryption.secretRef` on every Kustomization.

**Verdict:** Accurately addressed.

### Missing 4: No mention of SOPS as CNCF Sandbox project -- FIXED

Line 125 now reads: `[SOPS](https://github.com/getsops/sops) (CNCF Sandbox) -- encrypted file editor supporting age, AWS KMS, GCP KMS, Azure Key Vault`

The "(CNCF Sandbox)" annotation is accurate. SOPS was accepted into the CNCF Sandbox in May 2023 and remains at Sandbox level as of February 2026.

**Verdict:** Accurately addressed.

### Missing 5: No mention of Kubernetes etcd encryption at rest -- FIXED

A new row has been added to the Anti-Patterns table (line 121):

| Do not | Why |
|---|---|
| Unencrypted etcd | Kubernetes etcd does not encrypt Secrets at rest by default -- configure `EncryptionConfiguration` or KMS provider |

This accurately captures the key point: Kubernetes Secrets in etcd are base64-encoded, not encrypted, and administrators must explicitly configure encryption. The `EncryptionConfiguration` and KMS provider are the two standard approaches, both mentioned in the official Kubernetes documentation.

**Verdict:** Accurately addressed. Well-placed in the Anti-Patterns table.

### Missing 6: No mention of secret scanning/detection tooling -- NOT FIXED

There is no mention of pre-commit hooks, gitleaks, trufflehog, GitHub secret scanning, or other "shift-left" secrets detection tools.

**Severity:** Low. The skill is focused on SOPS encryption workflows, not the broader CI/CD security pipeline. A reference to detection tooling would strengthen it but its absence does not make the existing content incorrect.

### Missing 7: SOPS latest version context -- NOT FIXED (Acceptable)

The skill does not mention SOPS version requirements or note which version introduced the subcommand syntax. However, SOPS v3.9.0 (which introduced subcommands) is now nearly two years old, making this less of a concern than it was. Users running any reasonably current version will have subcommand support.

**Severity:** Negligible. This was a "nice to have" in the original review.

---

## New Issues Introduced by the Fixes

**None identified.** The fixes are clean additions and modifications that do not introduce technical inaccuracies, structural problems, or contradictions.

Specific checks performed:
- All SOPS commands use consistent subcommand syntax (no mixing of old and new)
- The workflow steps remain sequentially coherent
- The new Anti-Patterns row is factually accurate
- The new Patterns entries (ESO, Flux v2.7) are technically correct
- The replacement reference URL is live and relevant
- Line count (129) remains within the 150-line budget
- The `.sops.yaml` example, encrypted manifest example, and age keygen command are unchanged and remain correct

---

## References Check (Updated)

| Reference | Status | Notes |
|-----------|--------|-------|
| [SOPS](https://github.com/getsops/sops) (CNCF Sandbox) | Active | Correct. CNCF Sandbox annotation added. Latest v3.11.0. |
| [age](https://github.com/FiloSottile/age) | Active | Correct. Latest v1.3.1 (Dec 2025). |
| [Flux SOPS guide](https://fluxcd.io/flux/guides/mozilla-sops/) | Active | Correct. Page is live and current. |
| [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) | Active | Correct. Page is live. |
| [Kubernetes Secrets good practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) | Active | NEW. Replaces incorrect book reference. Verified live, last modified June 2025. |

All five references are valid, live URLs pointing to authoritative sources.

---

## Final Verdict

**Score: 9/10**

The updated skill addresses all four concrete Issues (outdated SOPS syntax, incorrect book reference, incomplete key rotation workflow, table/workflow inconsistency) and five of the seven Missing items (ESO mention, Flux v2.7 global decryption, CNCF Sandbox status, etcd encryption, replacement reference). The fixes are technically accurate, well-written, and do not introduce new problems.

The two remaining gaps (age post-quantum support, secret scanning tooling) are both low-severity informational items that do not affect the correctness of the skill's guidance. They would push the score to a perfect 10 if addressed, but their absence does not meaningfully diminish the skill's utility for its target audience.

The skill is now a reliable, up-to-date reference for SOPS-based secrets management in a Kubernetes/Flux GitOps environment.

---

**Reviewed:** 2026-02-18
**Reviewer:** Claude Opus 4.6
**Skill file:** `/home/lukas/claude-code-skills/skills/secrets-management/SKILL.md`
**Skill lines:** 129 (within 150-line budget)
**Previous review:** `/home/lukas/claude-code-skills/docs/reviews/secrets-review.md`
**SOPS latest:** v3.11.0 (2025-09-28)
**age latest:** v1.3.1 (2025-12-28)
**Flux latest:** v2.7 GA (2025-10)
