# Review: secrets-management

## Score: 7/10

The skill file is well-structured, follows the project template (Principles, Standards, Workflow, Patterns, Anti-Patterns, References), stays under 150 lines, and covers the core SOPS + age workflow accurately. However, it uses outdated SOPS CLI syntax, omits several important developments (post-quantum age, Flux v2.7 global SOPS decryption, External Secrets Operator as an alternative), and has an incorrect book reference. These issues collectively bring the score down from what would otherwise be a strong 9.

---

## Findings

### Accurate

- **YAML frontmatter** follows the project's Claude Code skill format correctly: `name`, `description`, `allowed-tools` all present and well-formed. Consistent with sibling skills like `kubernetes-gitops` and `clean-code-principles`.
- **Principles section** is solid. "Never plaintext in Git", "Encrypt at rest and in transit", "Least privilege", "Rotate regularly", "Audit access", "Defense in depth" -- all align with OWASP Secrets Management Cheat Sheet recommendations and remain current best practice.
- **"Encrypt values, not keys"** is correctly stated. SOPS's key differentiator is that it keeps YAML/JSON keys readable while encrypting only values. The `ENC[AES256_GCM,data:...,type:str]` format shown in the encrypted manifest example is correct.
- **`.sops.yaml` configuration** using `creation_rules` with `path_regex` and per-environment `age` recipients is correct and remains the recommended approach. This pattern is well-documented in both the SOPS docs and the Flux SOPS guide.
- **"age over PGP"** recommendation is correct and strengthened by the fact that the Flux SOPS guide now explicitly states: "age is a simple, modern alternative to OpenPGP. It's recommended to use age over OpenPGP, if possible."
- **`age-keygen -o key.txt`** command is correct for generating an age keypair.
- **Anti-patterns table** is comprehensive and accurate. All items (Dockerfile ENV/ARG, `.env` in Git, shared secrets across environments, unrotated tokens, secrets in CI logs, hardcoded secrets, base64 as "encryption") are legitimate anti-patterns still called out in current best-practice guides.
- **cert-manager** mention is appropriate. cert-manager remains the standard for TLS certificate automation in Kubernetes (latest: v1.19.3, released February 2026, still a CNCF project).
- **Separate age identity per environment** is a sound pattern and correctly positioned.
- **Kubernetes Secrets from SOPS manifests** with controller decryption at deploy time is correctly described.
- **Runtime secrets via env vars** is the correct recommendation.
- **Overall structure** follows the Principles -> Standards -> Workflow -> Patterns We Use -> Anti-Patterns -> References template defined in the design doc.
- **Line count** is 124 lines, within the 150-line budget.

### Issues

#### 1. Outdated SOPS CLI syntax (flag-based instead of subcommands)

**What it says:** The skill uses `sops -e -i`, `sops -d`, `sops -r -i` throughout the Workflow and Quick-reference sections.

**What it should say:** Since SOPS 3.9.0 (released 2024), proper subcommands were introduced: `sops encrypt`, `sops decrypt`, `sops rotate`, `sops edit`. The old flag syntax (`-e`, `-d`, `-r`) still works but is on a long-term deprecation path. The official SOPS documentation and README now use the subcommand syntax exclusively.

Updated commands:

| Task | Old (in skill) | New (recommended) |
|------|----------------|-------------------|
| Encrypt file in place | `sops -e -i <file>` | `sops encrypt -i <file>` |
| Decrypt to stdout | `sops -d <file>` | `sops decrypt <file>` |
| Edit encrypted file | `sops <file>` | `sops edit <file>` |
| Rotate data key | `sops -r -i <file>` | `sops rotate -i <file>` |
| Encrypt specific keys | `sops -e --encrypted-regex ... -i <file>` | `sops encrypt --encrypted-regex ... -i <file>` |

**Source:** https://github.com/getsops/sops/issues/1333, https://getsops.io/docs/

#### 2. Incorrect book reference

**What it says:** `"Security Chaos Engineering" -- Kennedy, Nolan`

**What it should say:** The book "Security Chaos Engineering: Sustaining Resilience in Software and Systems" is authored by **Kelly Shortridge and Aaron Rinehart**, published by O'Reilly Media (2023). There are no authors named "Kennedy" or "Nolan" associated with this book. Kennedy Torkura is mentioned only in the acknowledgments as an early SCE community pioneer.

This reference should either be corrected to the right authors or replaced with a more directly relevant reference (e.g., the Kubernetes Secrets good practices guide).

**Source:** https://www.oreilly.com/library/view/security-chaos-engineering/9781492080350/

#### 3. Incomplete key rotation workflow

**What it says (line 77-79):**
```bash
sops updatekeys secret.yaml
```
as the "Rotate keys" step.

**What it should say:** `sops updatekeys` syncs recipients from `.sops.yaml` into the file but does NOT rotate the data encryption key. For a proper key rotation (especially after removing a recipient), you need both steps:
1. `sops updatekeys secret.yaml` -- sync recipients from `.sops.yaml`
2. `sops rotate -i secret.yaml` -- generate a new data encryption key

When removing a recipient, both steps are required. The old data key must be rotated so the removed recipient cannot decrypt with a previously-obtained data key. The skill conflates "update recipients" with "rotate keys", which are distinct operations.

**Source:** https://github.com/getsops/sops, SOPS documentation on key rotation

#### 4. Quick-reference table has both operations but doesn't explain the distinction

**What it says:** The quick-reference table lists both "Rotate data key" (`sops -r -i`) and "Update recipients" (`sops updatekeys`) separately, which is correct. However, the Workflow section (step 7) only shows `sops updatekeys` as the "Rotate keys" step, which creates confusion. The table and the workflow disagree.

**What it should say:** The workflow step 7 should be labeled "Update recipients and rotate data key" and show both commands, or be split into two steps.

### Missing

#### 1. No mention of External Secrets Operator (ESO)

The External Secrets Operator is now a mature Kubernetes project (v1.3.2, GA on Red Hat OpenShift as of late 2025) and represents the primary alternative approach to SOPS for Kubernetes secrets. ESO syncs secrets from external vaults (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, GCP Secret Manager) into Kubernetes Secrets at runtime, with automatic rotation.

The skill should mention ESO as an alternative in a brief "Alternatives" or "When to use something else" section, explaining the trade-off: SOPS is encrypt-in-Git (GitOps-native, simple), while ESO is vault-backed (dynamic rotation, centralized management, better for multi-cluster). Many production teams use both.

**Source:** https://external-secrets.io/, https://github.com/external-secrets/external-secrets

#### 2. No mention of age v1.3.0 post-quantum support

age v1.3.0 (released late 2025) introduced post-quantum hybrid encryption using ML-KEM-768. This is a significant development:
- New recipient format: `age1pq1...` (post-quantum) alongside classic `age1...`
- Post-quantum and classic recipients cannot be mixed in a single file
- New `age-keygen -pq` flag for generating post-quantum keypairs
- New `age-inspect` tool for examining encrypted file metadata
- SOPS does not yet appear to support `age1pq1...` recipients

This should be noted as an emerging development, even if not yet actionable for SOPS workflows.

**Source:** https://github.com/FiloSottile/age/releases/tag/v1.3.0

#### 3. No mention of Flux v2.7 global SOPS decryption

Flux v2.7 (GA October 2025) introduced global SOPS decryption for age keys via the `--sops-age-secret` controller flag. This eliminates the need to configure `.spec.decryption.secretRef` on every Kustomization. The skill mentions "Flux kustomize-controller with SOPS decryption provider" but does not reference this newer, simpler pattern.

**Source:** https://fluxcd.io/blog/2025/09/flux-v2.7.0/, https://fluxcd.io/flux/components/kustomize/kustomizations/

#### 4. No mention of SOPS as a CNCF Sandbox project

SOPS was accepted as a CNCF Sandbox project in May 2023. This is relevant context for its maturity and long-term viability. It remains at Sandbox level as of February 2026.

**Source:** https://www.cncf.io/projects/sops/

#### 5. No mention of Kubernetes etcd encryption at rest

The skill mentions "Encrypt at rest and in transit" as a principle and covers SOPS encryption for Git, but does not mention that Kubernetes etcd does NOT encrypt Secrets at rest by default. This is a critical complementary concern -- SOPS handles the Git side, but teams also need `EncryptionConfiguration` or KMS integration on the cluster side for etcd encryption. A one-liner in the Standards or Anti-Patterns section would be appropriate.

**Source:** https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

#### 6. No mention of secret scanning / detection tooling

The OWASP Cheat Sheet emphasizes "shift-left" secrets detection (pre-commit hooks, CI scanners like gitleaks, trufflehog, GitHub secret scanning). The skill covers secret hygiene from the encryption side but not the detection/prevention side. A brief mention in Anti-Patterns or a reference link would strengthen the skill.

#### 7. SOPS latest version context

The skill does not mention SOPS version requirements or note that the syntax shown requires a particular version. SOPS v3.11.0 is the latest (September 2025). Notable recent additions include `sops set --value-file`, `sops set --value-stdin`, and YAML list format for keys in `.sops.yaml`. These are minor but worth being aware of.

**Source:** https://github.com/getsops/sops/releases/tag/v3.11.0

### References Check

| Reference | Status | Notes |
|-----------|--------|-------|
| [SOPS](https://github.com/getsops/sops) | Active | Repository active, 20.8k stars, latest v3.11.0 (Sep 2025). Description accurately states "age, AWS KMS, GCP KMS, Azure Key Vault" but the actual tool also supports HuaweiCloud KMS. Minor omission. |
| [age](https://github.com/FiloSottile/age) | Active | Repository active, 21.3k stars, latest v1.3.1 (Dec 2025). Description "simple, modern file encryption" is accurate. |
| [Flux SOPS guide](https://fluxcd.io/flux/guides/mozilla-sops/) | Active | Page is live, title is now "Manage Kubernetes secrets with SOPS" (not "Mozilla SOPS"). Content is current and covers age as recommended over PGP. |
| [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) | Active | Page is live, content is current with 11 sections. Still a relevant and authoritative reference. |
| "Security Chaos Engineering" -- Kennedy, Nolan | INCORRECT | Authors are Kelly Shortridge and Aaron Rinehart, NOT Kennedy and Nolan. This reference needs correction or replacement. |

### Recommendations

1. **Update all SOPS commands to subcommand syntax.** Replace `sops -e -i` with `sops encrypt -i`, `sops -d` with `sops decrypt`, `sops -r -i` with `sops rotate -i`, and `sops <file>` with `sops edit <file>`. The old flag syntax is on a deprecation path since SOPS 3.9.0.

2. **Fix or replace the book reference.** Either correct to "Security Chaos Engineering -- Shortridge, Rinehart (O'Reilly, 2023)" or replace with a more directly relevant reference such as the [Kubernetes Secrets good practices guide](https://kubernetes.io/docs/concepts/security/secrets-good-practices/).

3. **Fix the key rotation workflow (step 7).** Distinguish between `sops updatekeys` (sync recipients) and `sops rotate -i` (rotate data key). Show both when describing key rotation, and clarify that both are needed when removing a recipient.

4. **Add a brief note about External Secrets Operator** in the Patterns or References section, positioning it as the alternative for teams that prefer vault-backed dynamic secrets over encrypt-in-Git. One to two lines is sufficient.

5. **Add a note about age post-quantum support** as an emerging feature. Even a single line like "age v1.3+ supports post-quantum hybrid keys (`age1pq1...`); SOPS support pending" keeps the skill forward-looking.

6. **Add a note about Flux v2.7 global SOPS decryption** (`--sops-age-secret` flag) as an improvement over per-Kustomization `.spec.decryption.secretRef` configuration.

7. **Add CNCF Sandbox status** to the SOPS reference line, e.g., "SOPS (CNCF Sandbox) -- encrypted file editor...".

8. **Add one line about etcd encryption at rest** to the Standards or Anti-Patterns table, noting that Kubernetes Secrets in etcd are not encrypted by default and require `EncryptionConfiguration` or KMS provider setup.

9. **Consider adding a reference** to secret scanning tools (gitleaks, trufflehog) or the OWASP CI/CD Security Cheat Sheet for the detection side of secret hygiene.

---

**Reviewed:** 2026-02-18
**Reviewer:** Claude Opus 4.6
**Skill file:** `/home/lukas/claude-code-skills/skills/secrets-management/SKILL.md`
**Skill lines:** 124 (within 150-line budget)
**SOPS latest:** v3.11.0 (2025-09-28)
**age latest:** v1.3.1 (2025-12-28)
**Flux latest:** v2.7 GA (2025-10)
**cert-manager latest:** v1.19.3 (2026-02-02)
**ESO latest:** v1.3.2
