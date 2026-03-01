# openfang-agent-orchestration

Claude Code skill for managing OpenFang agents via the `openfang-ctl` CLI tool.

## Overview

This skill enables Claude Code to orchestrate OpenFang agents running in the homelab Kubernetes cluster. OpenFang agents are autonomous AI assistants powered by Claude models that can execute long-running tasks independently.

## What This Skill Does

- Spawns new OpenFang agents with specific tasks and model selections
- Lists all active agents in the cluster
- Monitors agent status and retrieves logs
- Stops agents after task completion

## Prerequisites

1. **openfang-ctl CLI** installed on the system (available via NixOS on homelab hosts)
2. **OpenFang central API** running at `openfang-central.sammasak.dev`
3. **Configuration file** at `~/.config/openfang/config.toml` with API endpoint and key

## Usage

Claude Code can use this skill to:

1. **Spawn agents for parallel work:**
   ```bash
   openfang-ctl agents spawn --name "docs-updater" --task "Update API documentation"
   ```

2. **Monitor running agents:**
   ```bash
   openfang-ctl agents list
   openfang-ctl agents status <agent-id>
   ```

3. **Stream agent logs:**
   ```bash
   openfang-ctl agents logs <agent-id> --follow
   ```

4. **Clean up completed agents:**
   ```bash
   openfang-ctl agents stop <agent-id>
   ```

## Architecture

```
Claude Code (skill) → openfang-ctl (CLI) → OpenFang Central API → OpenFang Agents
```

- **openfang-ctl**: Rust CLI tool for agent management
- **OpenFang Central API**: REST API running in Kubernetes workstations namespace
- **Agents**: Individual Claude-powered agents running tasks autonomously

## Related

- **Repository:** [sammasak/openfang-ctl](https://github.com/sammasak/openfang-ctl)
- **API:** OpenFang central API at `http://openfang-central-api.workstations.svc.cluster.local:4200`
- **Infrastructure:** Deployed via NixOS and Flux GitOps

## Maintainer

Lukas Sammasak (@sammasak)
