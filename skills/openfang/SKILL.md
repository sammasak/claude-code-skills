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

You'll override the endpoint per-instance with `--api-endpoint`. The key is always the same across all worker VMs.

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
  instancetypeName: openfang-agent
  runStrategy: Always
  exposedPorts:
    - {name: ssh, port: 22, protocol: TCP}
    - {name: openfang-api, port: 4200, protocol: TCP}
  idleHaltAfterMinutes: 1440
EOF
```

Naming convention: `openfang-<project-slug>` — e.g., `openfang-harbor-metrics`, `openfang-jarvis-v2`.

### 4b-alt. Spawn an agent via direct API (openfang 0.2.3)

`openfang-ctl` 0.1.0 in the golden image is incompatible with `openfang` server 0.2.3. Use direct API calls until the image is updated.

The 0.2.3 API requires a `manifest_toml` body with a `[[hands]]` block. Available hands with `shell_exec`: `collector`, `lead`, `predictor`, `researcher`. Use `collector` for GitOps/infrastructure work.

```bash
LB_IP=$(kubectl get svc openfang-<name>-ssh -n workstations \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

OPENFANG_KEY=$(sops -d ~/homelab-gitops/apps/workstations/secrets/openfang-worker-bootstrap.secret.yaml \
  | grep -oP 'api_key = "\K[^"]+')

# Create agent
AGENT_ID=$(curl -s -X POST "http://$LB_IP:4200/api/agents" \
  -H "Authorization: Bearer $OPENFANG_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"manifest_toml\": \"name = \\\"my-agent\\\"\nmodule = \\\"collector\\\"\n\n[model]\nprovider = \\\"anthropic\\\"\nmodel = \\\"claude-sonnet-4-20250514\\\"\n\n[[hands]]\nid = \\\"collector\\\"\"}" \
  | jq -r '.agent_id')

echo "Agent ID: $AGENT_ID"

# Send task
curl -s -X POST "http://$LB_IP:4200/api/agents/$AGENT_ID/message" \
  -H "Authorization: Bearer $OPENFANG_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"<task text here>\"}"

# Check state
curl -s -H "Authorization: Bearer $OPENFANG_KEY" \
  "http://$LB_IP:4200/api/agents/$AGENT_ID" | jq .

# Kill agent
curl -s -X DELETE \
  -H "Authorization: Bearer $OPENFANG_KEY" \
  "http://$LB_IP:4200/api/agents/$AGENT_ID"
```

Minimal manifest_toml (unescaped for reference):

```toml
name = "my-agent"
module = "collector"

[model]
provider = "anthropic"
model = "claude-sonnet-4-20250514"

[[hands]]
id = "collector"
```

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
echo "  SSH:         ssh lukas@$LB_IP"
echo "  openfang API: http://$LB_IP:4200  (once controller fix is deployed)"
echo "  openfang API: ssh lukas@$LB_IP 'OPENFANG_API_ENDPOINT=http://localhost:4200 openfang-ctl ...'"
```

Note: port 4200 will be on the LoadBalancer after a controller fix is deployed (tracked). Until then, use SSH to run openfang-ctl locally on the VM.

Verify openfang API is up (allow 60-90s after vmStatus=Running for cloud-init):
```bash
curl -s http://$LB_IP:4200/api/agents | jq .
```

### 4e. Stop VM (pause, data persists)

```bash
curl -s -X POST https://workstations-api.sammasak.dev/api/v1/workspaces/openfang-project-name/stop | jq .
```

Resume later with `/start`. The workspace PVC and all committed git work survives.

### 4f. List All openfang VMs

```bash
kubectl get workspaceclaim -n workstations \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,VM:.status.vmStatus' \
  | grep "^openfang"
```

### 4g. Delete VM (permanent)

```bash
kubectl delete workspaceclaim openfang-project-name -n workstations
```

This deletes the WorkspaceClaim — controller removes the VM, PVC, and Service via owner-reference cascade.

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
# Note: if port 4200 is not yet on the LoadBalancer, use SSH to run openfang-ctl on the VM:
# ssh lukas@$LB_IP 'export OPENFANG_API_ENDPOINT=http://localhost:4200 && openfang-ctl agents spawn ...'

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
| kubectl apply returns "already exists" | WorkspaceClaim already exists | Use different name or kubectl delete then re-apply |
| VM stuck in "Pending" | Image pull or scheduling issue | `kubectl describe vm openfang-<name> -n workstations` |
| openfang API not responding on :4200 | Cloud-init still running | Wait 90s after vmStatus=Running |
| `openfang-ctl` auth fail | Wrong API key | Re-check worker bootstrap secret API key |
| Agent stops immediately | Bad task or missing tool | `openfang-ctl agents logs $ID` for error |
| Agent stuck in loop | Under-specified brief | Stop, add Out of Scope constraints, respawn |
| git push fails in logs | GH_TOKEN expired | Wait up to 50 min for auto-refresh |
| kubectl fails inside VM | kubeconfig issue | `ssh lukas@$LB_IP kubectl get nodes` |
| LB_IP returns null/empty | Service not yet assigned | Wait 30s and retry; check kubectl get svc -n workstations |
| Port 4200 unreachable on LB_IP | Controller fix not yet deployed | SSH to VM and run openfang-ctl locally (localhost:4200) |
| `openfang-ctl agents spawn` fails with "missing field manifest_toml" | openfang-ctl 0.1.0 is incompatible with openfang server 0.2.3; API changed | Use direct curl API calls: `POST /api/agents` with `{"manifest_toml": "..."}` body — see Section 4b-alt |
| Agent Running but LLM auth fails (401 invalid x-api-key) | ANTHROPIC_API_KEY in bootstrap secret is an expired OAuth token (`sk-ant-oat01-...`) | Rotate: generate fresh regular API key from https://console.anthropic.com → API Keys → Create new key; update bootstrap secret with `sops`; commit and push; delete and recreate the VM (bootstrap is read at cloud-init time) |
