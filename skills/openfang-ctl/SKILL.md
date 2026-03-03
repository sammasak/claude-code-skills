---
name: openfang-ctl
description: "Use when running openfang-ctl CLI commands to manage openfang VMs and agents. Quick reference for all commands and flags."
allowed-tools: Bash
---

# openfang-ctl CLI Reference

## Config (`~/.config/openfang/config.toml`)

```toml
workspace_api_url = "https://workstations-api.sammasak.dev"
api_key = "<openfang api key>"
skills_dir = "~/.claude/skills"
```

Initialize: `openfang-ctl init`

## Workspaces (manages KubeVirt VMs via workstation-api)

```bash
openfang-ctl workspaces list
openfang-ctl workspaces create <name>
openfang-ctl workspaces delete <name>
openfang-ctl workspaces provision <name>   # create + wait + inject skills + activate hand
```

Naming convention: `openfang-<project-slug>`

## Agents (manages agents on a specific openfang VM)

```bash
# --endpoint required (or OPENFANG_ENDPOINT env)
openfang-ctl agents list     --endpoint http://IP:4200
openfang-ctl agents status   --endpoint http://IP:4200 <agent_id>
openfang-ctl agents message  --endpoint http://IP:4200 <agent_id> "goal text"
openfang-ctl agents messages --endpoint http://IP:4200 <agent_id> [--follow]
openfang-ctl agents stop     --endpoint http://IP:4200 <agent_id>
```

## Hands (pre-built agent personalities)

```bash
openfang-ctl hands list     --endpoint http://IP:4200
openfang-ctl hands activate --endpoint http://IP:4200 researcher
```

Researcher hand: autonomous executor with shell_exec, file ops, web tools.
Auto-activated on every VM boot by cloud-init.

## API key

Get from bootstrap secret:
```bash
sops -d ~/homelab-gitops/apps/workstations/secrets/openfang-worker-bootstrap.secret.yaml \
  | grep api_key | head -1
```
