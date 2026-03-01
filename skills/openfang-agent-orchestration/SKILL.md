> **See the `openfang` skill** for the full VM + agent lifecycle workflow:
> provision a VM, write project briefs, spawn agents, monitor, intervene, and complete tasks.
>
> This document is the **openfang-ctl CLI quick-reference**.

---

# OpenFang Agent Orchestration

Manage OpenFang agents using the openfang-ctl CLI tool.

## When to Use

- Spawning new OpenFang agents for autonomous tasks
- Monitoring agent status and logs
- Stopping agents after task completion
- Listing all active agents in the homelab

## Prerequisites

- openfang-ctl installed (available on homelab hosts via NixOS)
- An openfang VM running and its LoadBalancer IP known (see the `openfang` skill for provisioning)
- Configuration file at ~/.config/openfang/config.toml (or use environment variables)

## Core Operations

### Initialize Configuration

First-time setup to create config file with API endpoint:

```bash
openfang-ctl init
```

This creates `~/.config/openfang/config.toml` with:
- API endpoint (defaults to cluster-internal service)
- API key placeholder (update with actual key)

### List Active Agents

View all agents and their status:

```bash
openfang-ctl agents list
```

Shows table with: ID, Name, Status, Model, Created timestamp

### Spawn New Agent

Create a new agent with a task:

```bash
openfang-ctl agents spawn \
  --name "log-analyzer" \
  --task "Analyze system logs for errors in the last 24 hours" \
  --model sonnet
```

**Available models:**
- `sonnet` (default) - Claude Sonnet 4.5, balanced performance
- `opus` - Claude Opus 4.6, highest capability
- `haiku` - Claude Haiku 3.5, fastest/cheapest

### Check Agent Status

Get detailed status for a specific agent:

```bash
openfang-ctl agents status <agent-id>
```

Shows: status, model, task description, timestamps

### View Agent Logs

Stream logs from an agent:

```bash
# View recent logs
openfang-ctl agents logs <agent-id>

# Follow logs in real-time
openfang-ctl agents logs <agent-id> --follow
```

### Stop Agent

Stop a running agent:

```bash
openfang-ctl agents stop <agent-id>
```

Prompts for confirmation. Use `--force` to skip.

## Configuration

### Config File

Location: `~/.config/openfang/config.toml`

```toml
# No default endpoint — override per-instance:
api_key = "your-api-key-here"
```

Endpoint is set per-command using `--api-endpoint`:

```bash
openfang-ctl --api-endpoint http://<LB_IP>:4200 agents list
```

### Environment Variables

Override config with environment variables:

```bash
export OPENFANG_API_ENDPOINT="http://localhost:4200"
export OPENFANG_API_KEY="your-key"
```

### CLI Arguments

Override per-command:

```bash
openfang-ctl --api-endpoint http://localhost:4200 agents list
```

**Priority:** CLI args > Environment variables > Config file

## Common Workflows

### Quick Agent Spawn

```bash
# Spawn agent for system analysis
openfang-ctl agents spawn \
  --name "system-check" \
  --task "Check cluster health and report issues" \
  --model sonnet
```

### Monitor Agent Lifecycle

```bash
# Spawn agent
AGENT_ID=$(openfang-ctl agents spawn --name "task" --task "..." | grep -oP 'ID: \K[^\s]+')

# Follow logs
openfang-ctl agents logs $AGENT_ID --follow

# When done, stop agent
openfang-ctl agents stop $AGENT_ID
```

### List and Clean Up

```bash
# List all agents
openfang-ctl agents list

# Stop all stopped agents (manual cleanup)
openfang-ctl agents list | grep stopped | awk '{print $1}' | xargs -I {} openfang-ctl agents stop {} --force
```

## Troubleshooting

### Connection Refused

**Symptom:** `Failed to connect to API`

**Solution:**
1. Check openfang API on the target VM:
   ```bash
   # Check openfang API on the target VM
   curl http://<LB_IP>:4200/api/agents

   # If VM is Running but API not responding, SSH in:
   ssh lukas@<LB_IP> 'sudo systemctl status openfang'
   ```

2. Check API endpoint in config:
   ```bash
   cat ~/.config/openfang/config.toml
   ```

### Authentication Failed

**Symptom:** `401 Unauthorized`

**Solution:**
1. Verify API key in config file
2. Check environment variables: `env | grep OPENFANG`
3. Request new API key if expired

### Agent Not Responding

**Symptom:** Agent status stuck in "pending"

**Solution:**
1. Verify agent resources:
   ```bash
   openfang-ctl agents status <agent-id>
   ```

## Notes

- Agents run on a per-project on-demand VM provisioned via the `openfang` skill
- Log streaming polls every 2 seconds (not real-time WebSocket)
- API key required for authentication (stored in config file or env var)
- Confirm before stopping agents (prevents accidental termination)

## Related Skills

- kubernetes-gitops: For debugging agent infrastructure
- observability-patterns: For monitoring agent metrics in Grafana
