---
name: secrets-management
description: "Use when handling secrets, encryption keys, credentials, tokens, or sensitive configuration. Guides SOPS encryption workflows, Kubernetes secret patterns, and secret hygiene."
allowed-tools: Bash Read Grep Glob
---

# Secrets Management

Protect credentials throughout their lifecycle: generation, storage, deployment, rotation, and revocation.

## Principles

- **Never plaintext in Git** -- encrypted or external, no exceptions
- **Encrypt at rest and in transit** -- secrets protected in storage and over the wire
- **Least privilege** -- services get only the secrets they need, nothing more
- **Rotate regularly** -- automate rotation where possible; assume eventual compromise
- **Audit access** -- know who accessed what and when
- **Defense in depth** -- multiple layers; no single control is sufficient

## Standards

| Rule | Detail |
|---|---|
| SOPS for file-level encryption | GitOps-friendly -- encrypted files live in Git |
| `.sops.yaml` at repo root | Defines path patterns mapped to key recipients |
| Encrypt values, not keys | Diffs remain reviewable: you see WHICH secret changed, not the value |
| K8s Secrets from SOPS manifests | Controller decrypts at deploy time |
| Runtime secrets via env vars | Never baked into container images |
| Separate keys per environment | Dev key cannot decrypt prod |
| Secret files in `.gitignore` | Only encrypted versions get committed |

### `.sops.yaml` example

```yaml
creation_rules:
  - path_regex: clusters/prod/.*\.secret\.yaml$
    age: age1prod...  # prod recipient
  - path_regex: clusters/staging/.*\.secret\.yaml$
    age: age1staging...  # staging recipient
  - path_regex: clusters/dev/.*\.secret\.yaml$
    age: age1dev...  # dev recipient
```

### Encrypted manifest structure

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: app-credentials
    namespace: app
type: Opaque
stringData:
    db-password: ENC[AES256_GCM,data:...,type:str]  # value encrypted
    api-token: ENC[AES256_GCM,data:...,type:str]     # keys stay readable
```

## Workflow

```
generate --> configure --> create --> encrypt --> commit --> deploy --> rotate --> verify
```

1. **Generate age keypair**
   ```bash
   age-keygen -o key.txt
   # Public key: age1abc...
   ```
2. **Configure `.sops.yaml`** with path rules and the age public key
3. **Create secret file** (plain YAML with sensitive values)
4. **Encrypt in place**
   ```bash
   sops -e -i secret.yaml
   ```
5. **Commit encrypted file** to Git (plaintext never touches a commit)
6. **Deploy** -- Flux SOPS kustomize-controller decrypts at apply time
7. **Rotate keys**
   ```bash
   sops updatekeys secret.yaml
   ```
8. **Verify decryption**
   ```bash
   sops -d secret.yaml
   ```

### Quick-reference commands

| Task | Command |
|---|---|
| Encrypt file in place | `sops -e -i <file>` |
| Decrypt to stdout | `sops -d <file>` |
| Edit encrypted file | `sops <file>` |
| Rotate data key | `sops -r -i <file>` |
| Update recipients | `sops updatekeys <file>` |
| Encrypt specific keys | `sops -e --encrypted-regex '^(data\|stringData)$' -i <file>` |

## Patterns We Use

- **age over PGP** -- simpler key management, no key servers, no expiry headaches
- **SOPS for all GitOps secrets** -- works with Flux natively, encrypted files live alongside manifests
- **Flux kustomize-controller** with SOPS decryption provider -- secrets decrypted only at deploy time in-cluster
- **Separate age identity per environment** -- dev, staging, prod each hold their own key; compromise is isolated
- **Kubernetes Secrets** for service credentials -- DB passwords, API tokens, managed via SOPS-encrypted manifests
- **cert-manager** for TLS certificates -- automated issuance and renewal, no manual cert management

## Anti-Patterns

| Do not | Why |
|---|---|
| Secrets in `Dockerfile` ENV/ARG | Visible in `docker history` output |
| Commit `.env` files to Git | Plaintext credentials in repository history forever |
| Share secrets across environments | Breach in dev becomes breach in prod |
| Never-rotated tokens | Assume breach; rotate proactively |
| Secrets in CI pipeline logs | Mask all secret variables in CI configuration |
| Hardcoded secrets in source code | Use environment variables or config injection |
| base64 as "encryption" | K8s Secrets are base64-encoded, not encrypted -- anyone with API access reads them |

## References

- [SOPS](https://github.com/getsops/sops) -- encrypted file editor supporting age, AWS KMS, GCP KMS, Azure Key Vault
- [age](https://github.com/FiloSottile/age) -- simple, modern file encryption
- [Flux SOPS guide](https://fluxcd.io/flux/guides/mozilla-sops/) -- integrating SOPS with Flux GitOps
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- "Security Chaos Engineering" -- Kennedy, Nolan
