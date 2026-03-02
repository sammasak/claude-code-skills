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
- You **communicate via the researcher hand** — the auto-activated agent that has shell and file tools
- openfang **executes autonomously** — commits work to git, deploys via Flux, verifies
- You **review** the output (git log, kubectl, curl success criteria)
- You **stop or delete** the VM when done (or keep for long-running projects)

VMs are persistent — stopping a VM preserves the workspace PVC (data). You can resume later.

> **IMPORTANT: openfang-ctl 0.1.0 is INCOMPATIBLE with openfang server 0.2.3.** Do not use `openfang-ctl agents spawn` — it calls `POST /api/agents` which always produces tool-less agents (tool_count=0). Use the researcher hand workflow described in Section 5.

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

### 4a. Prerequisites — Configure Your Local API Key

Get the openfang API key from the worker bootstrap secret (same key for all worker VMs):

```bash
OPENFANG_KEY=$(sops -d ~/homelab-gitops/apps/workstations/secrets/openfang-worker-bootstrap.secret.yaml \
  | grep -oP 'api_key = "\K[^"]+')
echo "Key: $OPENFANG_KEY"
```

Add it to your local config:
```bash
mkdir -p ~/.config/openfang
cat > ~/.config/openfang/config.toml <<EOF
api_key = "$OPENFANG_KEY"
EOF
```

For subsequent commands, export as an env var:
```bash
OPENFANG_API_KEY=$(grep api_key ~/.config/openfang/config.toml | cut -d'"' -f2)
```

The key is always the same across all worker VMs. Do not use openfang-ctl (incompatible with server 0.2.3).

### 4b. Create a VM

```bash
kubectl apply -n workstations -f - <<EOF
apiVersion: workstations.sammasak.dev/v1alpha1
kind: WorkspaceClaim
metadata:
  name: openfang-project-name
  namespace: workstations
spec:
  containerDiskImage: registry.sammasak.dev/agents/openfang-agent:latest
  bootstrapSecretName: openfang-worker-bootstrap
  instancetypeName: openfang-central
  runStrategy: Always
  exposedPorts:
    - {name: ssh, port: 22, protocol: TCP}
    - {name: openfang-api, port: 4200, protocol: TCP}
  idleHaltAfterMinutes: 1440
EOF
```

Naming convention: `openfang-<project-slug>` — e.g., `openfang-harbor-metrics`, `openfang-jarvis-v2`.

### 4c. Wait for Ready

```bash
# Poll until VM is Running
watch -n 5 'kubectl get workspaceclaim openfang-project-name -n workstations \
  -o jsonpath="{.status.phase} {.status.vmStatus}"'
```

Ready when: `phase = "Ready"`, `vmStatus = "Running"`.

### 4d. Capture the Endpoint

```bash
LB_IP=$(kubectl get svc openfang-project-name-ssh -n workstations \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "SSH/openfang endpoint: $LB_IP"
echo "  SSH:          ssh lukas@$LB_IP"
echo "  openfang API: http://$LB_IP:4200"
```

Verify openfang API is up (allow 60-90s after vmStatus=Running for cloud-init):
```bash
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" http://$LB_IP:4200/api/agents | jq .
```

### 4e. VM Boot Verification — Confirm Researcher Hand is Active

After cloud-init completes, the researcher hand auto-activates. Allow up to 120s after vmStatus=Running:

```bash
# Verify researcher hand is active (auto-activates via cloud-init, allow 120s after vmStatus=Running)
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/hands/active | jq '.[0] | {hand_id, status, agent_id}'
# Should show: {"hand_id": "researcher", "status": "Active", "agent_id": "..."}
```

If the array is empty, wait and retry. See the Troubleshooting table for debug steps.

### 4f. Stop VM (pause, data persists)

```bash
curl -s -X POST https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name/stop | jq .
```

Resume later with `/start`. The workspace PVC and all committed git work survives.

### 4g. List All openfang VMs

```bash
kubectl get workspaceclaim -n workstations \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,VM:.status.vmStatus' \
  | grep "^openfang"
```

### 4h. Delete VM (permanent)

```bash
kubectl delete workspaceclaim openfang-project-name -n workstations
```

This deletes the WorkspaceClaim — controller removes the VM, PVC, and Service via owner-reference cascade.

---

## Section 5: Agent Lifecycle — Spawn, Monitor, Intervene, Stop

> **IMPORTANT: openfang-ctl 0.1.0 is INCOMPATIBLE with openfang server 0.2.3.** Do not use `openfang-ctl agents spawn` — it calls `POST /api/agents` which always produces tool-less agents (tool_count=0). The manifest_toml approach never activates hands/tools. Use the researcher hand workflow below.

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

### 5b. Spawn an Agent — Researcher Hand Workflow

The researcher hand is **auto-activated on every VM boot** via cloud-init. It has 15 tools: shell_exec, file_read, file_write, file_list, web_fetch, web_search, memory_store, memory_recall, and more. Use it directly instead of spawning a new agent via openfang-ctl.

**Step 1: Get the auto-activated researcher hand agent ID:**
```bash
OPENFANG_API_KEY=$(grep api_key ~/.config/openfang/config.toml | cut -d'"' -f2)

AGENT_ID=$(curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/hands/active | jq -r '.[0].agent_id')
echo "Researcher agent: $AGENT_ID"
```

**Step 2: Send the project brief as a message to that agent:**
```bash
PROJECT_BRIEF="$(cat <<'EOF'
[paste full project brief here]
EOF
)"

curl -s -X POST \
  -H "Authorization: Bearer $OPENFANG_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"content\": $(echo "$PROJECT_BRIEF" | jq -Rs .)}" \
  http://$LB_IP:4200/api/agents/$AGENT_ID/message
```

**Step 3: Confirm the agent has tools (tool_count should be >0):**
```bash
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/agents/$AGENT_ID | jq '{status: .status, tool_count: (.capabilities.tools | length)}'
# Should show tool_count: 15 (or similar non-zero value)
```

### 5c. Monitor

```bash
OPENFANG_API_KEY=$(grep api_key ~/.config/openfang/config.toml | cut -d'"' -f2)

# Get latest messages from the researcher agent
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/agents/$AGENT_ID/messages | jq '.[-10:] | .[] | {role: .role, content: .content[:200]}'

# Check agent status and tool count
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/agents/$AGENT_ID | jq '{status: .status, tool_count: (.capabilities.tools | length)}'

# Poll for the 5 most recent messages
curl -s -H "Authorization: Bearer $OPENFANG_API_KEY" \
  http://$LB_IP:4200/api/agents/$AGENT_ID/messages | jq '.[-5:]'
```

Healthy signs: varied tool calls, git commits in target repo, status progresses.
Stuck signs: same tool 3+ times, >5 min silence, repeated auth errors.

### 5d. Intervene

For VM-level issues (tools missing, config wrong):
```bash
ssh lukas@$LB_IP
sudo systemctl status openfang
journalctl -u openfang -n 50
# For bootstrap issues:
journalctl -t openfang-bootstrap -n 50
```

To send a corrective message to the researcher agent:
```bash
CORRECTION="Updated brief — add 'Do NOT...' constraints for what went wrong"

curl -s -X POST \
  -H "Authorization: Bearer $OPENFANG_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"content\": $(echo "$CORRECTION" | jq -Rs .)}" \
  http://$LB_IP:4200/api/agents/$AGENT_ID/message
```

Review what was committed:
```bash
cd ~/homelab-gitops && git log --oneline -10
```

### 5e. Complete

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
| kubectl apply returns "already exists" | WorkspaceClaim already exists | Use different name or kubectl delete then re-apply |
| VM stuck in "Pending" | Image pull or scheduling issue | `kubectl describe vm openfang-<name> -n workstations` |
| openfang API not responding on :4200 | Cloud-init still running | Wait 90s after vmStatus=Running |
| Agent stops immediately | Bad task or missing tool | Check messages via REST API |
| Agent stuck in loop | Under-specified brief | Send corrective message via REST API with added Out of Scope constraints |
| git push fails in logs | GH_TOKEN expired | Wait up to 50 min for auto-refresh |
| kubectl fails inside VM | kubeconfig issue | `ssh lukas@$LB_IP kubectl get nodes` |
| LB_IP returns null/empty | Service not yet assigned | Wait 30s and retry; check kubectl get svc -n workstations |
| `GET /api/hands/active` returns empty array | Researcher hand not yet activated | Wait 120s after vmStatus=Running; check `journalctl -t openfang-bootstrap` on VM via SSH |
| openfang-ctl auth fail or tool_count=0 | Using openfang-ctl (incompatible with 0.2.3) | Use REST API directly with researcher hand workflow (Section 5b) |
| Agent Running but LLM auth fails (401 invalid x-api-key) | ANTHROPIC_API_KEY in bootstrap secret is an expired OAuth token (`sk-ant-oat01-...`) | Rotate: generate fresh regular API key from https://console.anthropic.com → API Keys → Create new key; update bootstrap secret with `sops`; commit and push; delete and recreate the VM (bootstrap is read at cloud-init time) |
