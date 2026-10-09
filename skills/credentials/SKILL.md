---
name: credentials
description: "Use when running build, push, or deploy commands that need credentials (registry auth, API keys, tokens) in this homelab."
allowed-tools: Bash, Read
---

# Credentials

Before running any command that requires credentials, load them from the correct source.

## Credential Sources (priority order)

| Source | Location | Use for |
|---|---|---|
| Environment vars | Already set in shell | Highest priority — use if present |
| `~/.env` | `~/.env` | API keys, OAuth tokens, misc secrets (list non-exhaustive — read the file) |
| Container registry auth | `~/.config/containers/auth.json` | `skopeo`, `podman`, `buildah`, registry pushes |
| SOPS secrets | `~/homelab-gitops/` or `~/nixos-config/secrets/` | Kubernetes secrets, NixOS service secrets |

## Loading `~/.env`

Always source `~/.env` before running build or deploy commands if credentials might be needed:

```bash
set -a && source ~/.env && set +a
```

Contains: `CLAUDE_CODE_OAUTH_TOKEN` (local override; sops-nix also provides it at `/run/secrets/claude_oauth_token`), `GEMINI_API_KEY`, `CLOUDFLARE_API_TOKEN`, `TAILSCALE_AUTH_KEY`, `ACME_EMAIL`.

## Container Registry (zot)

Registry: `registry.sammasak.dev` (zot, robot-account auth — Harbor is retired).

Credentials are stored in `~/.config/containers/auth.json`. Extract them when needed:

```bash
auth_encoded=$(jq -r '.auths["registry.sammasak.dev"].auth' ~/.config/containers/auth.json)
robot_user=$(echo "$auth_encoded" | base64 -d | cut -d: -f1)
robot_pass=$(echo "$auth_encoded" | base64 -d | cut -d: -f2-)
```

Or pass the authfile directly to skopeo:

```bash
skopeo copy --authfile ~/.config/containers/auth.json oci:./dir docker://registry.sammasak.dev/lab/<app>:<tag>
```

skopeo and buildah also read this file by default, so plain `skopeo copy ... docker://registry.sammasak.dev/...` pushes work without flags.

## SOPS Secrets

Decrypt a SOPS file to read a secret:

```bash
sops -d ~/homelab-gitops/apps/<app>/secrets/some.secret.yaml
```

Flux's kustomize-controller decrypts the same files in-cluster via each Kustomization's `spec.decryption` (`secretRef: sops-age`) — the age private key never leaves the cluster or your local age identity. Never write plaintext secrets to `/tmp` — always decrypt in place or to the correct repo path (see `secrets-management` skill for the full lifecycle).

## Checklist Before Running Build/Push Commands

- [ ] Does the command need registry auth? → skopeo/buildah read `~/.config/containers/auth.json` by default; pass `--authfile` if a tool doesn't
- [ ] Does the command need API keys? → `set -a && source ~/.env && set +a`
- [ ] Does the command need a SOPS secret? → `sops -d <file>` and use the value directly
- [ ] Are env vars already set? → Check with `env | grep -i registry` or similar before loading
