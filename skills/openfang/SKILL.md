---
name: openfang
description: "Use when creating, assigning projects to, monitoring, or managing openfang AI agent VMs. Covers the full lifecycle: provision VM, write project brief, spawn agent, monitor, intervene, stop, delete."
allowed-tools: Bash, Read, Grep, Glob
---

# openfang On-Demand VM + Agent Lifecycle

## Section 1: When to Use

Use openfang for projects requiring multi-step autonomous execution — multiple files, multiple systems, multiple deploy steps.

**Use for:**
- Build and deploy a new homelab service (design → GitOps manifest → push → verify)
- Refactor or extend an existing service (read codebase → implement → commit → PR)
- Write architecture docs or runbooks (research → draft → commit to knowledge-vault)
- Multi-step infrastructure changes (CRD → controller → claims → verify)

**Don't use for:** quick kubectl queries, single-file edits, anything done in <5 tool calls.

---

## Section 2: Mental Model

**openfang VM = staff engineer. You (Claude Code or human) = tech lead.**

- You **provision** the VM (workspace-api)
- You **assign** a project brief (`openfang-ctl agents spawn`)
- openfang **executes autonomously** — commits work to git, deploys via Flux, verifies
- You **review** the output (git log, kubectl, curl success criteria)
- You **stop or delete** the VM when done (or keep for long-running projects)

VMs are persistent — stopping a VM preserves the workspace PVC (data). You can resume later.

---

## Section 3: What an openfang VM Can Do

| Capability | Tool | Notes |
|---|---|---|
| Read cluster state | `kubectl` | pods, events, logs, describe — kubeconfig at /etc/workstation/kubeconfig |
| Trigger GitOps deploy | `flux` | reconcile kustomization/helmrelease, get status |
| Push to sammasak repos | `git` + `gh` | GH_TOKEN auto-refreshes every 50 min |
| Edit SOPS secrets | `sops` + `age` | age key at ~/.config/sops/age/keys.txt |
| Process YAML/JSON | `yq` + `jq` | read/modify manifest fields |
| Inspect Helm releases | `helm` | helm get values, helm history |
| Browser automation | Playwright | headless Chrome for testing/scraping |
| GitOps patterns | skill: kubernetes-gitops | conventions, Flux workflow |
| Service engineering | skills: rust/python/nix | build services, NixOS modules |
| Observability | skill: observability-patterns | Grafana, PromQL, Loki |
| Secret management | skill: secrets-management | SOPS/age, never plaintext |

**GitOps-first operating pattern:**
1. `kubectl get/describe/logs` — understand current state
2. `git clone homelab-gitops`, edit manifests, `git push`
3. `flux reconcile kustomization <name>` — deploy
4. `kubectl` + `curl` — verify

openfang does NOT `kubectl apply` directly. All changes go through git → Flux.

---

## Section 4: VM Lifecycle — Create, Start, Stop, Delete

### 4a. Prerequisites — Configure Your Local openfang-ctl

Get the openfang API key from the worker bootstrap secret (same key for all worker VMs):

```bash
sops -d ~/homelab-gitops/apps/workstations/secrets/openfang-worker-bootstrap.secret.yaml | grep api_key
```

Add it to your local config:
```bash
mkdir -p ~/.config/openfang
cat > ~/.config/openfang/config.toml <<EOF
api_key = "<value-from-grep>"
EOF
```

You'll override the endpoint per-instance with `--api-endpoint`. The key is always the same across all worker VMs.

### 4b. Create a VM

```bash
curl -s -X POST https://workstations-api.sammasak.dev/api/v1/workspaces \
  -H "Content-Type: application/json" \
  -d '{
    "name": "openfang-project-name",
    "containerDiskImage": "registry.sammasak.dev/agents/openfang-agent:latest",
    "bootstrapSecretName": "openfang-worker-bootstrap",
    "instancetypeName": "openfang-agent",
    "runStrategy": "Always",
    "exposedPorts": [
      {"name": "ssh", "port": 22, "protocol": "TCP"},
      {"name": "openfang-api", "port": 4200, "protocol": "TCP"}
    ],
    "tailscale": {"expose": true, "hostname": "openfang-project-name", "tags": "tag:agent"},
    "idleHaltAfterMinutes": 1440
  }' | jq .
```

Naming convention: `openfang-<project-slug>` — e.g., `openfang-harbor-metrics`, `openfang-jarvis-v2`.

### 4c. Wait for Ready

```bash
# Poll until vmStatus = "Running"
watch -n 5 'curl -s https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name | jq "{phase: .phase, vmStatus: .vmStatus, ip: .loadBalancerIp}"'
```

Ready when: `phase = "Ready"`, `vmStatus = "Running"`, `loadBalancerIp` is set.

### 4d. Capture the Endpoint

```bash
LB_IP=$(curl -s https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name | jq -r .loadBalancerIp)
echo "VM endpoint: http://$LB_IP:4200"

# Verify openfang API is up (allow 60-90s after vmStatus=Running for cloud-init)
curl -s http://$LB_IP:4200/api/agents | jq .
```

### 4e. Stop VM (pause, data persists)

```bash
curl -s -X POST https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name/stop | jq .
```

Resume later with `/start`. The workspace PVC and all committed git work survives.

### 4f. List All openfang VMs

```bash
curl -s https://workstations-api.sammasak.dev/api/v1/workspaces | jq '.[] | select(.name | startswith("openfang")) | {name, phase, vmStatus, ip: .loadBalancerIp}'
```

### 4g. Delete VM (permanent)

```bash
curl -s -X DELETE https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name
```

This deletes the WorkspaceClaim — controller removes the VM, PVC, and Service.

---

## Section 5: Agent Lifecycle — Spawn, Monitor, Intervene, Stop

### 5a. Project Brief Template

```
## Goal
[What should exist when this task is complete that doesn't exist now]

## Context
- Repo(s): https://github.com/sammasak/[repo] — [what it is]
- Related services: [what this interacts with, endpoints, namespaces]
- Reference: [similar existing thing — "follow the pattern of apps/lab/whoami/"]
- Cluster access: kubectl configured, kubeconfig at /etc/workstation/kubeconfig

## Deliverables
1. [Concrete artifact — a file, a deployed service, a committed PR]
2. [Another artifact]

## Success Criteria
- [ ] [Observable, verifiable — "kubectl get pods -n <ns> shows 1/1 Running"]
- [ ] ["curl https://service.sammasak.dev returns HTTP 200"]
- [ ] ["flux get kustomization apps shows Ready=True"]

## Out of Scope
- [Explicitly state what NOT to touch]
- [e.g., "do not modify existing secrets, only create new ones"]
```

Model guidance: `sonnet` for most work, `opus` for deep architectural reasoning.

### 5b. Spawn an Agent

```bash
# Point openfang-ctl at the specific VM
export OPENFANG_API_ENDPOINT="http://$LB_IP:4200"

AGENT_ID=$(openfang-ctl agents spawn \
  --name "descriptive-kebab-case-name" \
  --task "$(cat <<'EOF'
[paste full project brief here]
EOF
)" \
  --model sonnet | grep -oP 'ID: \K[^\s]+')

echo "Agent ID: $AGENT_ID"
```

### 5c. Monitor

```bash
export OPENFANG_API_ENDPOINT="http://$LB_IP:4200"

openfang-ctl agents logs --follow $AGENT_ID    # live log stream
openfang-ctl agents status $AGENT_ID           # phase check
openfang-ctl agents list                       # all agents on this VM
```

Healthy signs: varied tool calls, git commits in target repo, status progresses.
Stuck signs: same tool 3+ times, >5 min silence, repeated auth errors.

### 5d. Intervene

```bash
# Stop the agent
openfang-ctl agents stop --force $AGENT_ID

# Review what was committed
cd ~/homelab-gitops && git log --oneline -10

# Respawn with corrected brief
openfang-ctl agents spawn \
  --name "name-v2" \
  --task "Updated brief — add 'Do NOT...' constraints for what went wrong"
```

For VM-level issues (tools missing, config wrong):
```bash
ssh lukas@$LB_IP
sudo systemctl status openfang
journalctl -u openfang -n 50
```

### 5e. Complete

```bash
openfang-ctl agents stop $AGENT_ID
```

Post-completion checklist:
- [ ] Review git commits: `git log --oneline -10` in target repo
- [ ] Flux reconciled: `flux get kustomizations`
- [ ] Success criteria met: kubectl, curl
- [ ] No plaintext secrets: `git diff HEAD~5 | grep -iE 'password|secret|token|key'`
- [ ] Grafana: no new alerts at https://grafana.sammasak.dev
- [ ] Stop or delete the VM if no longer needed

---

## Section 6: Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| workspace-api returns 409 | Name already exists | Use different name or delete old one |
| VM stuck in "Pending" | Image pull or scheduling issue | `kubectl describe vm openfang-<name> -n workstations` |
| openfang API not responding on :4200 | Cloud-init still running | Wait 90s after vmStatus=Running |
| `openfang-ctl` auth fail | Wrong API key | Re-check worker bootstrap secret API key |
| Agent stops immediately | Bad task or missing tool | `openfang-ctl agents logs $ID` for error |
| Agent stuck in loop | Under-specified brief | Stop, add Out of Scope constraints, respawn |
| git push fails in logs | GH_TOKEN expired | Wait up to 50 min for auto-refresh |
| kubectl fails inside VM | kubeconfig issue | `ssh lukas@$LB_IP kubectl get nodes` |
