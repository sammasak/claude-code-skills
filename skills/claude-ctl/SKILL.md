---
name: claude-ctl
description: "Use when creating, assigning tasks to, monitoring, or tearing down claude-worker autonomous agent VMs. Covers the full lifecycle via claude-ctl."
allowed-tools: Bash, Read
injectable: true
---

# claude-ctl

Manage claude-worker autonomous agent VMs via the `claude-ctl` CLI.

## Commands

### `init`
Initialise config at `~/.config/claude-ctl/config.toml`. No-op if config already exists.
```bash
claude-ctl init
```

### `provision <name>`
Create a VM, wait for it to be ready, optionally seed a goal and stream its output.
```bash
claude-ctl provision <name>
claude-ctl provision <name> --goal "Build and deploy X"
claude-ctl provision <name> --goal "..." --watch   # stream SSE output until done/failed
```
- Waits up to 10 min for `vmStatus=Running` + IP
- Waits up to 2 min for claude-worker HTTP API at `<IP>:4200`
- Prints a summary box: name, IP, endpoint, goal ID

### `goal <name> <text>`
Post a goal to an already-running VM.
```bash
claude-ctl goal <name> "Refactor the auth module"
claude-ctl goal <name> "..." --watch   # stream SSE until done/failed
```

### `delete <name>`
Tear down a VM. Idempotent — 404 is treated as success.
```bash
claude-ctl delete <name>
```

## Configuration

**File:** `~/.config/claude-ctl/config.toml`
```toml
workspace_api_url = "https://workstations-api.sammasak.dev"
```

**Env overrides:**
| Variable | Overrides |
|---|---|
| `CLAUDE_CTL_WORKSPACE_API_URL` | `workspace_api_url` |

## VM Defaults (hard-coded in binary)

| Field | Value |
|---|---|
| Container image | `registry.sammasak.dev/agents/claude-worker:latest` |
| Bootstrap secret | `claude-worker-bootstrap` |
| Instance type | `openfang-agent` |
| Run strategy | `Always` |
| Idle halt | 1440 min (24 h) |

## Workflow

```
provision → (wait) → goal → watch SSE → delete
```

1. `claude-ctl provision worker-1 --goal "..." --watch` — fire and monitor
2. Or: provision first, post goals later with `claude-ctl goal worker-1 "..."`
3. When done: `claude-ctl delete worker-1`

## SSE Stream Events

`--watch` streams Server-Sent Events from `/goals/{id}/stream`:
- `[DONE]` — goal completed successfully
- `[FAILED ...]` — goal failed with reason
- Hook events: `tool_start`, `file_op`, `goal_loop`, `review_start`, `session_end`
- Raw assistant/tool/result JSON objects
