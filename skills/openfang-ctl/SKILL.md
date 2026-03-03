---
name: openfang-ctl
description: "Use when running openfang-ctl CLI commands to manage openfang VMs and agents. Quick reference for all commands and flags."
allowed-tools: Bash
---

# openfang-ctl CLI Reference (v0.4.0)

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
openfang-ctl workspaces provision <name>              # create + wait + inject all skills + activate researcher
openfang-ctl workspaces provision <name> --skills a,b # inject only named skills
openfang-ctl workspaces provision <name> --no-skills  # skip skill injection
```

Naming convention: `openfang-<project-slug>`

## Agents (manages agents on a specific openfang VM)

```bash
# --endpoint required (or OPENFANG_ENDPOINT env)
openfang-ctl agents list     --endpoint http://IP:4200
openfang-ctl agents status   --endpoint http://IP:4200 <agent_id>
openfang-ctl agents logs     --endpoint http://IP:4200 <agent_id> [--follow]
openfang-ctl agents message  --endpoint http://IP:4200 <agent_id> "goal text"
openfang-ctl agents messages --endpoint http://IP:4200 <agent_id> [-n 20]
openfang-ctl agents stop     --endpoint http://IP:4200 <agent_id> [--force]
```

## Hands (pre-built agent personalities)

```bash
openfang-ctl hands list     --endpoint http://IP:4200
openfang-ctl hands activate --endpoint http://IP:4200 researcher
```

Researcher hand: autonomous executor with shell_exec, file ops, web tools.
Auto-activated on every VM boot by cloud-init.

## Skills (local and remote management)

```bash
# Local skills only
openfang-ctl skills list

# Local + remote injection status (shows ✓/– per skill)
openfang-ctl skills list --endpoint http://IP:4200

# Inject one skill
openfang-ctl skills add <name> --endpoint http://IP:4200

# Inject all local skills
openfang-ctl skills add --all --endpoint http://IP:4200
```

Local skills are read from `skills_dir` (default `~/.claude/skills`).
Each skill must be a subdirectory containing `SKILL.md`.

## API key

Get from bootstrap secret:
```bash
sops -d ~/homelab-gitops/apps/workstations/secrets/openfang-worker-bootstrap.secret.yaml \
  | grep api_key | head -1
```
