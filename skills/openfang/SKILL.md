---
name: openfang
description: "Use when creating, assigning tasks to, monitoring, or tearing down openfang AI agent VMs. Covers the full lifecycle via openfang-ctl."
allowed-tools: Bash
---

# openfang — Autonomous Agent Workflow

## When to Use

Use openfang for multi-step autonomous execution:
- Build and deploy a new service (design → code → GitOps → verify)
- Refactor or extend an existing codebase
- Write architecture docs or runbooks
- Multi-step infrastructure changes

**Don't use for:** quick kubectl queries, single-file edits, anything done in <5 tool calls.

## Mental Model

openfang VM = staff engineer. You = tech lead giving a goal.

- You **provision** the VM — skills are injected automatically
- You **send one goal message** describing the end state
- openfang **executes autonomously** using its skills
- You **monitor** progress and **review** the output
- You **teardown** when done

## Workflow

### 1. Provision

```bash
openfang-ctl workspaces provision openfang-<project-slug>
# Waits for VM ready, injects skills, activates researcher hand
# Prints: endpoint + agent_id
```

Naming: `openfang-<project-slug>` e.g. `openfang-twitter-backend`, `openfang-harbor-metrics`

### 2. Send goal

```bash
openfang-ctl agents message <agent_id> \
  --endpoint http://<IP>:4200 \
  "Goal: <describe end state>. Success: <observable criteria>. Out of scope: <what NOT to touch>."
```

**Goal format:**
```
Goal: Build a FastAPI pastebin service that stores pastes in Redis with TTL.
Success: kubectl get pods -n lab shows 1/1 Running; curl https://paste.sammasak.dev returns HTTP 200.
Out of scope: Do not modify existing ingress rules. Do not touch harbor.
```

### 3. Monitor

```bash
openfang-ctl agents messages <agent_id> --endpoint http://<IP>:4200 --follow
```

Healthy: varied tool calls, git commits appearing in target repo.
Stuck: same tool repeated 3+ times, >5 min silence.

If stuck, send a corrective message:
```bash
openfang-ctl agents message <agent_id> --endpoint http://<IP>:4200 \
  "Clarification: <add constraint or hint>"
```

### 4. Verify completion

```bash
git log --oneline -10   # in target repo
flux get kustomizations
kubectl get pods -n <namespace>
```

### 5. Teardown

```bash
openfang-ctl workspaces delete openfang-<project-slug>
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `workspaces provision` fails at VM wait | `kubectl describe workspaceclaim <name> -n workstations` |
| openfang API not responding | Wait 90s after vmStatus=Running for cloud-init |
| Skill injection returns 4xx | Check endpoint, continue (non-fatal) |
| Agent stuck in loop | Send corrective message with added Out of Scope constraints |
| LLM auth error | Check GEMINI_API_KEY in bootstrap secret |
