---
name: credentials
description: "Use when running build, push, or deploy commands that need credentials (registry auth, API keys, tokens). Guides how to load credentials from the correct sources in this homelab."
allowed-tools: Bash, Read
injectable: true
---

# Credentials

Before running any command that requires credentials, load them from the correct source.

## Credential Sources (priority order)

| Source | Location | Use for |
|---|---|---|
| Environment vars | Already set in shell | Highest priority — use if present |
| `~/.env` | `~/.env` | API keys, OAuth tokens, misc secrets |
| Container registry auth | `~/.config/containers/auth.json` | `skopeo`, `podman`, `buildah`, registry pushes |
| SOPS secrets | `~/homelab-gitops/` or `~/nixos-config/secrets/` | Kubernetes secrets, NixOS service secrets |

## Loading `~/.env`

Always source `~/.env` before running build or deploy commands if credentials might be needed:

```bash
set -a && source ~/.env && set +a
```

Contains: `CLAUDE_CODE_OAUTH_TOKEN`, `GROK_API_KEY`, and other personal API keys.

## Container Registry (Harbor)

Registry: `registry.sammasak.dev`

Credentials are stored in `~/.config/containers/auth.json`. Extract them when needed:

```bash
auth_encoded=$(jq -r '.auths["registry.sammasak.dev"].auth' ~/.config/containers/auth.json)
harbor_user=$(echo "$auth_encoded" | base64 -d | cut -d: -f1)
harbor_pass=$(echo "$auth_encoded" | base64 -d | cut -d: -f2-)
```

Or pass the authfile directly to skopeo:

```bash
skopeo copy --authfile ~/.config/containers/auth.json oci:./dir docker://registry.sammasak.dev/project/image:tag
```

> `publish-oci-image.sh` auto-reads `auth.json` — no env vars needed for image pushes.

## SOPS Secrets

Decrypt a SOPS file to read a secret:

```bash
sops -d ~/homelab-gitops/apps/workstations/secrets/some.secret.yaml
```

Never write plaintext secrets to `/tmp` — always decrypt in place or to the correct repo path.

## Checklist Before Running Build/Push Commands

- [ ] Does the command need registry auth? → `auth.json` is auto-used by `publish-oci-image.sh`; for manual `skopeo`/`podman` use `--authfile`
- [ ] Does the command need API keys? → `set -a && source ~/.env && set +a`
- [ ] Does the command need a SOPS secret? → `sops -d <file>` and use the value directly
- [ ] Are env vars already set? → Check with `env | grep -i harbor` or similar before loading
