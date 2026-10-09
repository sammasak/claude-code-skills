---
name: secrets-management
description: "Use when creating, encrypting, editing, or rotating a SOPS secret in homelab-gitops or nixos-config, changing age recipients, or wiring secret delivery (Flux decryption, sops-nix). Not for loading already-provisioned credentials at build or deploy time — route that to credentials. Not for application code that reads env vars or tokens at runtime."
allowed-tools: Bash, Read, Grep, Glob
---

# Secrets Management (homelab)

SOPS + age everywhere; no Sealed Secrets, no Vault.

## Where things live

| Repo | Rules file | Secret paths | Delivery |
|---|---|---|---|
| `~/homelab-gitops` | `.sops.yaml` at root (`encrypted_regex: ^(data\|stringData)$`) | `clusters/homelab/infra/secrets/`, `apps/<app>/secrets/*.secret.yaml` | Flux Kustomization `spec.decryption` with `secretRef: sops-age` (per Kustomization, not a global controller flag) |
| `~/nixos-config` | `secrets/.sops.yaml` | `secrets/{homelab,core,claude}/*.yaml` | sops-nix at activation; never in the Nix store |

Personal age key: `~/.config/sops/age/keys.txt`. Host age keys are generated per node by nixos-config. Every gitops rule has two recipients (personal + Flux `sops-age`); a file encrypted for only one breaks either local edit or in-cluster apply.

## Workflow

```bash
# new secret: generate, encrypt straight to the repo path
kubectl create secret generic <name> -n <ns> --from-literal=key=value --dry-run=client -o yaml \
  | sops -e --filename-override apps/<app>/secrets/<name>.secret.yaml /dev/stdin > apps/<app>/secrets/<name>.secret.yaml
sops apps/<app>/secrets/<name>.secret.yaml        # edit in place
sops updatekeys <file> && sops rotate -i <file>    # after changing recipients
```

- Never write plaintext to `/tmp`; write to the real repo path and `sops -e --in-place` so `.sops.yaml` path rules match.
- The filename must end `.secret.yaml` under `apps/`, or no creation rule matches.
- `apps/sandboxes/secrets/registry-secret.secret.yaml` is still named `harbor-registry-secret` but is a live zot pull secret. Leave the name alone (renaming needs re-encryption and a coordinated deploy).
- A plaintext secret that reached a commit must be rotated; rewriting history is not enough.
