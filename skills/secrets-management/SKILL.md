---
name: secrets-management
description: "Use when encrypting secrets with SOPS/age, managing Kubernetes Secret manifests, rotating credentials, or setting up secret delivery (sops-nix, sealed secrets). Not for application code that reads env vars or auth tokens at runtime."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Secrets Management

Protect credentials throughout their lifecycle: generation, storage, deployment, rotation, and revocation.

**CRITICAL: Never commit plaintext secrets to Git.** Encrypted or external, no exceptions. If you accidentally commit plaintext, rotate immediately — deleting the commit is not enough; history is the problem.

**IMPORTANT: Rotate after any team member departure, system compromise, or breach.** Assume the secret is known; act accordingly.

## Standards

| Rule | Detail |
|---|---|
| SOPS for file-level encryption | GitOps-friendly — encrypted files live in Git |
| `.sops.yaml` at repo root | Path patterns mapped to age key recipients |
| Encrypt values, not keys | Diffs remain reviewable — you see WHICH secret changed |
| Separate keys per environment | Dev key cannot decrypt prod |
| Runtime secrets via env vars | Never baked into container images |

### `.sops.yaml`

```yaml
creation_rules:
  - path_regex: clusters/prod/.*\.secret\.yaml$
    age: age1prod...
  - path_regex: clusters/dev/.*\.secret\.yaml$
    age: age1dev...
```

### Encrypted K8s Secret structure

```yaml
stringData:
    db-password: ENC[AES256_GCM,data:...,type:str]  # value encrypted
    api-token: ENC[AES256_GCM,data:...,type:str]     # keys stay readable
```

## SOPS Commands

| Task | Command |
|---|---|
| Encrypt in place | `sops encrypt -i <file>` |
| Decrypt to stdout | `sops decrypt <file>` |
| Edit encrypted file | `sops edit <file>` |
| Rotate data key | `sops rotate -i <file>` |
| Update recipients | `sops updatekeys <file>` |

**Never encrypt from `/tmp/`** — always write to the correct repo path then `sops -e --in-place`.

## Workflow

1. `age-keygen -o key.txt` — generate age keypair
2. Configure `.sops.yaml` with path rules and public key
3. Create secret file (plain YAML)
4. `sops encrypt -i secret.yaml` — encrypt in place
5. Commit encrypted file to Git
6. Flux kustomize-controller decrypts at apply time
7. Rotate: `sops updatekeys` then `sops rotate -i` (both needed when removing a recipient)

## Patterns We Use

- **age over PGP** — simpler key management, no key servers, no expiry
- **SOPS + Flux** — `--sops-age-secret` controller flag (Flux 2.7+) for global decryption
- **Separate age identity per environment** — compromise is isolated
- **cert-manager** for TLS — automated issuance and renewal

## Anti-Patterns

| Don't | Why |
|---|---|
| Secrets in `Dockerfile` ENV/ARG | Visible in `docker history` |
| Commit `.env` files | Plaintext in repository history forever |
| Share secrets across environments | Breach in dev becomes breach in prod |
| base64 as "encryption" | K8s Secrets are base64-encoded, not encrypted |
| Never-rotated tokens | Assume eventual compromise — rotate proactively |
| No secret scanning | Run `gitleaks` in pre-commit to catch plaintext early |
