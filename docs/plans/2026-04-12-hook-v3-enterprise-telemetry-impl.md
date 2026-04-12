# Hook v3 — Enterprise Telemetry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy the agent-telemetry hook: commit tagging, Prometheus metrics, Loki audit logs, and knowledge vault session notes — all fired from the Stop chain on VM goal completion.

**Architecture:** Four-stage `agent-telemetry` workflow lives in `~/workspace/workflows/hooks/agent-telemetry/run.sh` (editable without Nix rebuild). A 10-line dispatcher in `~/claude-code-skills/hooks/agent-telemetry.sh` wires it into Claude Code's Stop hook chain via `mcp.nix`. Prometheus Pushgateway is deployed via GitOps (it does not exist yet). Loki is already live at `monitoring-loki.monitoring.svc:3100`.

**Tech Stack:** Bash, curl, jq, git trailers, Prometheus text exposition format, Loki push API, `mcp.nix` NixOS Home Manager module, Flux GitOps (HelmRelease), SOPS secrets.

**Repos touched:**
- `~/homelab-gitops` — Pushgateway HelmRelease + bootstrap secret update
- `~/workspace` — agent-telemetry workflow (run.sh + CONTEXT.md)
- `~/claude-code-skills` — thin dispatcher hook + mcp.nix wiring
- `~/nixos-config` — mcp.nix Stop hook array entry

---

## Task 1: Deploy Prometheus Pushgateway via GitOps

Pushgateway does not exist in the cluster. We need it before push-metrics can work.

**Files:**
- Modify: `~/homelab-gitops/clusters/homelab/infra/observability.yaml`

**Step 1: Append Pushgateway HelmRelease to observability.yaml**

Open `~/homelab-gitops/clusters/homelab/infra/observability.yaml` and append at the end:

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: prometheus-pushgateway
  namespace: flux-system
spec:
  targetNamespace: monitoring
  interval: 15m
  chart:
    spec:
      chart: prometheus-pushgateway
      version: "~2.14.0"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    nodeSelector:
      node-pool: workers
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
    serviceMonitor:
      enabled: true
      namespace: monitoring
```

**Step 2: Commit and push**

```bash
cd ~/homelab-gitops
git add clusters/homelab/infra/observability.yaml
git commit -m "feat(monitoring): deploy prometheus-pushgateway for agent telemetry"
git push
```

**Step 3: Wait for Flux to reconcile and verify**

```bash
flux reconcile kustomization infra --with-source
kubectl rollout status deployment/prometheus-pushgateway -n monitoring --timeout=120s
kubectl get svc -n monitoring prometheus-pushgateway
```

Expected: service `prometheus-pushgateway` visible at port 9091.

---

## Task 2: Add PUSHGATEWAY_URL and LOKI_URL to claude-worker-bootstrap secret

VMs read their env from `.env` (written by cloud-init from the bootstrap secret). We need to add two new vars so run.sh can find the telemetry backends without hardcoding.

**Files:**
- Modify: `~/homelab-gitops/apps/workstations/secrets/claude-worker-bootstrap.secret.yaml`

**Step 1: Decrypt and edit the secret**

```bash
sops ~/homelab-gitops/apps/workstations/secrets/claude-worker-bootstrap.secret.yaml
```

Inside the SOPS editor, find the `.env` content block (it is inside the `userdata` field under a `write_files` entry with `path: /tmp/claude-worker-init/.env`). Add two lines at the end of the env block:

```
PUSHGATEWAY_URL=http://prometheus-pushgateway.monitoring.svc:9091
LOKI_URL=http://monitoring-loki.monitoring.svc:3100
```

Save and close the editor. SOPS re-encrypts automatically.

**Step 2: Verify the edit**

```bash
sops -d ~/homelab-gitops/apps/workstations/secrets/claude-worker-bootstrap.secret.yaml \
  | grep -E "PUSHGATEWAY|LOKI"
```

Expected: both lines present.

**Step 3: Commit and push**

```bash
cd ~/homelab-gitops
git add apps/workstations/secrets/claude-worker-bootstrap.secret.yaml
git commit -m "feat(workstations): add PUSHGATEWAY_URL and LOKI_URL to VM bootstrap env"
git push
```

---

## Task 3: Create agent-telemetry workflow in ~/workspace

This is the main logic file. All four stages live here. The dispatcher in claude-code-skills just sources this.

**Files:**
- Create: `~/workspace/workflows/hooks/agent-telemetry/CONTEXT.md`
- Create: `~/workspace/workflows/hooks/agent-telemetry/run.sh`

**Step 1: Write CONTEXT.md**

```markdown
# agent-telemetry

Stop hook workflow — fires on VM after check-goals.sh Phase 4 (clean exit).
VM-only (guards on goals.json presence).

## Purpose

After all goals complete and pass self-review, emit enterprise telemetry:

1. **tag-commits** (sync) — amend unpushed commits with `Goal-Id:` trailer
2. **push-metrics** (sync) — push Prometheus counters to Pushgateway
3. **emit-loki** (async) — POST structured goal completion log to Loki
4. **write-vault** (async) — commit session note to sammasak/workspace repo

## Environment variables

| Variable | Default | Source |
|----------|---------|--------|
| `PUSHGATEWAY_URL` | `http://prometheus-pushgateway.monitoring.svc:9091` | VM .env |
| `LOKI_URL` | `http://monitoring-loki.monitoring.svc:3100` | VM .env |
| `CLAUDE_WORKER_HOME` | `/var/lib/claude-worker` | systemd env |
| `CLAUDE_SESSION_ID` | set by Claude Code | Claude env |

## Loki query

```logql
{job="claude-worker"} | json | goal_id != ""
```

## Prometheus metrics

```promql
agent_goals_total{status="completed"}
agent_goal_duration_seconds
agent_review_score_last
```
```

**Step 2: Write run.sh** (the complete logic)

```bash
#!/usr/bin/env bash
# agent-telemetry/run.sh — Four-stage telemetry on goal completion
# Sourced by ~/claude-code-skills/hooks/agent-telemetry.sh (Stop hook dispatcher).
# VM-only: guards on goals.json existence.
# Stages 1+2 sync (<8s total). Stages 3+4 async background.

set -uo pipefail

WORKER_HOME="${CLAUDE_WORKER_HOME:-/var/lib/claude-worker}"
GOALS_FILE="$WORKER_HOME/goals.json"
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://prometheus-pushgateway.monitoring.svc:9091}"
LOKI_URL="${LOKI_URL:-http://monitoring-loki.monitoring.svc:3100}"
VM=$(hostname)
ICM_WORKSPACE="$WORKER_HOME/icm-workspace"

# Guard: VM-only
[ ! -f "$GOALS_FILE" ] && exit 0

# Guard: only run when all goals done (no pending/in_progress)
ACTIVE=$(jq '[.[] | select(.status == "pending" or .status == "in_progress")] | length' \
  "$GOALS_FILE" 2>/dev/null || echo "1")
[ "$ACTIVE" -gt 0 ] && exit 0

# Read last completed goal
GOAL=$(jq -c '[.[] | select(.status == "done")] | last' "$GOALS_FILE" 2>/dev/null || echo "null")
[ "$GOAL" = "null" ] || [ -z "$GOAL" ] && exit 0

GOAL_ID=$(echo "$GOAL" | jq -r '.id // "unknown"')
GOAL_TEXT=$(echo "$GOAL" | jq -r '.goal // ""')
REVIEW_SCORE=$(echo "$GOAL" | jq -r '.review_score // 0')
REVIEW_NOTE=$(echo "$GOAL" | jq -r '.review_note // ""')
GOAL_RESULT=$(echo "$GOAL" | jq -r '.result // ""')
STARTED_AT=$(echo "$GOAL" | jq -r '.started_at // ""')

# Calculate duration
NOW_S=$(date +%s)
if [ -n "$STARTED_AT" ] && [ "$STARTED_AT" != "null" ]; then
  START_S=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo "$NOW_S")
  DURATION_S=$(( NOW_S - START_S ))
else
  DURATION_S=0
fi

# Read repos_touched and tools_used from shared state
STATE_FILE="/tmp/claude-hook-state-${CLAUDE_SESSION_ID:-$$}.json"
REPOS_JSON="[]"
TOOLS_JSON="{}"
if [ -f "$STATE_FILE" ]; then
  REPOS_JSON=$(jq -c '.repos_touched // []' "$STATE_FILE" 2>/dev/null || echo "[]")
  TOOLS_JSON=$(jq -c '.tools_used // {}' "$STATE_FILE" 2>/dev/null || echo "{}")
fi
REPO=$(echo "$REPOS_JSON" | jq -r 'if length > 0 then .[0] else "unknown" end')

# ── Stage 1: tag-commits ──────────────────────────────────────────────────────
# Amend unpushed commits since goal start with Goal-Id: trailer.

TAGGED_COMMITS="[]"
AGENT_WORKSPACE="$WORKER_HOME/workspace"

if [ -d "$AGENT_WORKSPACE/.git" ] && [ -n "$STARTED_AT" ] && [ "$STARTED_AT" != "null" ]; then
  # Find commits since goal start that don't have Goal-Id trailer
  COMMITS=$(git -C "$AGENT_WORKSPACE" log \
    --format="%H" \
    --since="$STARTED_AT" \
    2>/dev/null || echo "")

  if [ -n "$COMMITS" ]; then
    # Find the upstream tracking branch to know what's been pushed
    UPSTREAM=$(git -C "$AGENT_WORKSPACE" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")

    while IFS= read -r SHA; do
      [ -z "$SHA" ] && continue

      # Skip if already has Goal-Id trailer
      TRAILER=$(git -C "$AGENT_WORKSPACE" log -1 --format="%B" "$SHA" 2>/dev/null \
        | grep "^Goal-Id:" || echo "")
      [ -n "$TRAILER" ] && continue

      # Skip if already pushed (commit reachable from upstream)
      if [ -n "$UPSTREAM" ]; then
        IS_PUSHED=$(git -C "$AGENT_WORKSPACE" branch -r --contains "$SHA" 2>/dev/null | head -1)
        [ -n "$IS_PUSHED" ] && continue
      fi

      # Amend with trailer (only works on HEAD for safety)
      HEAD_SHA=$(git -C "$AGENT_WORKSPACE" rev-parse HEAD 2>/dev/null || echo "")
      if [ "$SHA" = "$HEAD_SHA" ]; then
        git -C "$AGENT_WORKSPACE" commit --amend --no-edit \
          --trailer "Goal-Id: $GOAL_ID" \
          2>/dev/null && \
          TAGGED_COMMITS=$(echo "$TAGGED_COMMITS" | jq --arg s "$SHA" '. + [$s]')
      fi
    done <<< "$COMMITS"
  fi
fi

# ── Stage 2: push-metrics ─────────────────────────────────────────────────────
# Push Prometheus text exposition to Pushgateway.

SAFE_VM=$(echo "$VM" | tr -cs 'a-zA-Z0-9_' '_')
SAFE_REPO=$(echo "$REPO" | tr -cs 'a-zA-Z0-9_' '_')
SAFE_GOAL_ID=$(echo "$GOAL_ID" | tr -cs 'a-zA-Z0-9_' '_')

TOOL_CALLS_TOTAL=0
if [ "$TOOLS_JSON" != "{}" ]; then
  TOOL_CALLS_TOTAL=$(echo "$TOOLS_JSON" | jq '[to_entries[].value] | add // 0' 2>/dev/null || echo 0)
fi

METRICS_BODY="# HELP agent_goals_total Total goals completed by claude-worker agents
# TYPE agent_goals_total counter
agent_goals_total{status=\"completed\",vm=\"$SAFE_VM\",repo=\"$SAFE_REPO\"} 1

# HELP agent_goal_duration_seconds Duration from goal start to completion
# TYPE agent_goal_duration_seconds gauge
agent_goal_duration_seconds{vm=\"$SAFE_VM\",goal_id=\"$SAFE_GOAL_ID\"} $DURATION_S

# HELP agent_review_score_last Review score from self-review (0-10)
# TYPE agent_review_score_last gauge
agent_review_score_last{vm=\"$SAFE_VM\",goal_id=\"$SAFE_GOAL_ID\"} $REVIEW_SCORE

# HELP agent_tool_calls_total Total tool invocations this goal session
# TYPE agent_tool_calls_total counter
agent_tool_calls_total{vm=\"$SAFE_VM\",goal_id=\"$SAFE_GOAL_ID\"} $TOOL_CALLS_TOTAL
"

curl -sf \
  --max-time 4 \
  -X POST \
  "$PUSHGATEWAY_URL/metrics/job/claude-worker/instance/$SAFE_VM" \
  --data-binary "$METRICS_BODY" \
  -o /dev/null 2>/dev/null || true

# ── Stage 3: emit-loki (async) ────────────────────────────────────────────────
# POST structured goal completion entry to Loki push API.

NOW_NS=$(date +%s%N)
LOKI_LINE=$(jq -cn \
  --arg goal_id "$GOAL_ID" \
  --arg goal "$GOAL_TEXT" \
  --argjson review_score "$REVIEW_SCORE" \
  --arg review_note "$REVIEW_NOTE" \
  --argjson duration_s "$DURATION_S" \
  --argjson repos "$REPOS_JSON" \
  --argjson tools "$TOOLS_JSON" \
  --argjson commits "$TAGGED_COMMITS" \
  --arg vm "$VM" \
  '{
    goal_id: $goal_id,
    goal: $goal,
    status: "done",
    review_score: $review_score,
    review_note: $review_note,
    duration_s: $duration_s,
    repos_touched: $repos,
    tools_used: $tools,
    commits_tagged: $commits,
    hook: "agent-telemetry",
    vm: $vm
  }')

LOKI_PAYLOAD=$(jq -cn \
  --arg ts "$NOW_NS" \
  --arg vm "$VM" \
  --arg goal_id "$GOAL_ID" \
  --arg line "$LOKI_LINE" \
  '{
    streams: [{
      stream: {job: "claude-worker", vm: $vm, goal_id: $goal_id},
      values: [[$ts, $line]]
    }]
  }')

(curl -sf \
  --max-time 8 \
  -X POST \
  "$LOKI_URL/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d "$LOKI_PAYLOAD" \
  -o /dev/null 2>/dev/null || true) &

# ── Stage 4: write-vault (async) ──────────────────────────────────────────────
# Commit a session note to sammasak/workspace (ICM knowledge vault).

(
  # Lazy clone of ICM workspace repo
  if [ ! -d "$ICM_WORKSPACE/.git" ]; then
    git clone --depth=1 \
      "https://github.com/sammasak/workspace" \
      "$ICM_WORKSPACE" \
      2>/dev/null || exit 0
  else
    git -C "$ICM_WORKSPACE" pull --ff-only --quiet 2>/dev/null || true
  fi

  # Build session note filename
  DATE=$(date +%Y-%m-%d)
  SLUG=$(echo "$GOAL_TEXT" | tr '[:upper:]' '[:lower:]' | \
    tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/-*$//')
  NOTE_FILE="$ICM_WORKSPACE/sessions/ai-sessions/${DATE}-${GOAL_ID}-${SLUG}.md"

  # Build commits list
  COMMITS_MD=""
  if [ "$TAGGED_COMMITS" != "[]" ]; then
    while IFS= read -r sha; do
      [ -z "$sha" ] && continue
      SHORT=$(echo "$sha" | cut -c1-7)
      SUBJECT=$(git -C "$AGENT_WORKSPACE" log -1 --format="%s" "$sha" 2>/dev/null || echo "")
      COMMITS_MD="${COMMITS_MD}- \`$SHORT\` $SUBJECT"$'\n'
    done < <(echo "$TAGGED_COMMITS" | jq -r '.[]')
  fi
  [ -z "$COMMITS_MD" ] && COMMITS_MD="_none_"

  REPOS_MD=$(echo "$REPOS_JSON" | jq -r '.[] | "- \(.)"' 2>/dev/null || echo "_unknown_")
  [ -z "$REPOS_MD" ] && REPOS_MD="_unknown_"

  PROJECT=$(echo "$REPOS_JSON" | jq -r 'if length == 1 then .[0] else "multi" end' 2>/dev/null || echo "multi")

  cat > "$NOTE_FILE" << FRONTMATTER
---
date: $DATE
type: ai-session
project: $PROJECT
goal: "$GOAL_TEXT"
outcome: "$REVIEW_NOTE"
review_score: $REVIEW_SCORE
vm: $VM
goal_id: $GOAL_ID
---

# $GOAL_TEXT

## Outcome

$REVIEW_NOTE

## Work done

$GOAL_RESULT

## Repos touched

$REPOS_MD

## Commits

$COMMITS_MD
FRONTMATTER

  git -C "$ICM_WORKSPACE" add "sessions/ai-sessions/$(basename "$NOTE_FILE")"
  git -C "$ICM_WORKSPACE" commit \
    --author="claude-worker <noreply@sammasak.dev>" \
    -m "ai-session: $SLUG ($GOAL_ID)" \
    2>/dev/null || exit 0
  git -C "$ICM_WORKSPACE" push origin main 2>/dev/null || true
) &

# Wait for async stages to start (don't wait for completion — they're background)
wait 2>/dev/null || true

exit 0
```

**Step 3: Make run.sh executable**

```bash
chmod +x ~/workspace/workflows/hooks/agent-telemetry/run.sh
```

**Step 4: Update hooks INDEX.md**

Open `~/workspace/workflows/hooks/INDEX.md` and add a line to the prompt templates table:

```markdown
### agent-telemetry
- [[agent-telemetry/CONTEXT|agent-telemetry]] — four-stage VM telemetry: commit tagging, Prometheus metrics, Loki logs, vault session notes
```

**Step 5: Commit workspace changes**

```bash
cd ~/workspace
git add workflows/hooks/agent-telemetry/
git add workflows/hooks/INDEX.md
git commit -m "feat(hooks): add agent-telemetry workflow — commit tags, metrics, Loki, vault"
git push
```

---

## Task 4: Create thin dispatcher in claude-code-skills

**Files:**
- Create: `~/claude-code-skills/hooks/agent-telemetry.sh`

**Step 1: Write the dispatcher**

```bash
#!/usr/bin/env bash
# agent-telemetry — Stop hook dispatcher (VM only)
# Delegates all logic to ~/workspace/workflows/hooks/agent-telemetry/run.sh.
# Runs after write-session-state.sh in the Stop chain.
# Timeout: 60s (sync stages ~8s, async stages fire-and-forget).

WORKSPACE="${WORKSPACE:-$HOME/workspace}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/log.sh" 2>/dev/null || true
init_state 2>/dev/null || true

RUN_SH="$WORKSPACE/workflows/hooks/agent-telemetry/run.sh"

if [ ! -f "$RUN_SH" ]; then
  log_hook "agent-telemetry" "skip-no-workflow" "0" 2>/dev/null || true
  exit 0
fi

source "$RUN_SH"
```

**Step 2: Make executable**

```bash
chmod +x ~/claude-code-skills/hooks/agent-telemetry.sh
```

**Step 3: Commit**

```bash
cd ~/claude-code-skills
git add hooks/agent-telemetry.sh
git commit -m "feat(hooks): add agent-telemetry dispatcher — sources workspace workflow"
```

---

## Task 5: Wire agent-telemetry into mcp.nix Stop chain

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`

**Step 1: Find the Stop hooks array**

Open `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`. Locate the `Stop = [{ hooks = [` block. It currently ends with `write-session-state.sh`. Add `agent-telemetry.sh` immediately after it:

```nix
{
  type = "command";
  command = "${skillsSrc}/hooks/write-session-state.sh";
  timeout = 45;
}
{
  type = "command";
  command = "${skillsSrc}/hooks/agent-telemetry.sh";
  timeout = 60;
}
```

**Step 2: Commit**

```bash
cd ~/nixos-config
git add modules/programs/cli/claude-code/mcp.nix
git commit -m "feat(claude-code): wire agent-telemetry into Stop hook chain"
```

---

## Task 6: Update nixos-config flake inputs and rebuild

**Files:**
- Modify: `~/nixos-config/flake.nix` (flake update)

**Step 1: Update claude-code-skills flake input to pick up new hook**

```bash
cd ~/nixos-config
nix flake update claude-code-skills
```

Expected: `claude-code-skills` input updated to latest commit.

**Step 2: Rebuild**

```bash
sudo nixos-rebuild switch --flake .
```

Expected: switch completes, new settings.json written with agent-telemetry in Stop chain.

**Step 3: Verify settings.json has agent-telemetry**

```bash
grep "agent-telemetry" ~/.claude/settings.json
```

Expected: one line with the Nix store path to `agent-telemetry.sh`.

**Step 4: Commit flake.lock**

```bash
cd ~/nixos-config
git add flake.lock
git commit -m "chore: update claude-code-skills flake input (agent-telemetry hook)"
git push
```

---

## Task 7: Smoke test

There is no dedicated test harness for Stop hooks. We verify by simulating the conditions.

**Step 1: Check Pushgateway is up**

```bash
kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus-pushgateway
```

Expected: pod Running.

**Step 2: Dry-run run.sh with a fake goals.json**

```bash
# Create a fake completed goal
export CLAUDE_WORKER_HOME=/tmp/telemetry-test
export CLAUDE_SESSION_ID=test-session-001
export PUSHGATEWAY_URL=http://prometheus-pushgateway.monitoring.svc:9091
export LOKI_URL=http://monitoring-loki.monitoring.svc:3100
mkdir -p /tmp/telemetry-test

cat > /tmp/telemetry-test/goals.json << 'EOF'
[{
  "id": "test-001",
  "goal": "build a hello world app",
  "status": "done",
  "started_at": "2026-04-12T08:00:00Z",
  "result": "Created index.html with hello world",
  "review_score": 9,
  "review_note": "Complete and working"
}]
EOF

bash ~/workspace/workflows/hooks/agent-telemetry/run.sh
echo "exit: $?"
```

Expected: exit 0, no errors printed.

**Step 3: Verify Pushgateway received metrics**

```bash
curl -sf http://prometheus-pushgateway.monitoring.svc:9091/metrics \
  | grep agent_goals_total
```

Expected: `agent_goals_total{...} 1` line present.

**Step 4: Verify Loki received the log entry**

```bash
# Query Loki for the test entry (give async stage 5s to complete)
sleep 5
curl -sG "http://monitoring-loki.monitoring.svc:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="claude-worker"} | json | goal_id="test-001"' \
  | jq '.data.result[0].values[0][1]' 2>/dev/null
```

Expected: JSON string containing `"goal_id":"test-001"`.

**Step 5: Clean up test artifacts**

```bash
rm -rf /tmp/telemetry-test
curl -X DELETE \
  "http://prometheus-pushgateway.monitoring.svc:9091/metrics/job/claude-worker/instance/$(hostname)" \
  2>/dev/null || true
```

---

## Task 8: Push all commits

```bash
cd ~/claude-code-skills && git push
cd ~/homelab-gitops && git push
cd ~/nixos-config && git push
cd ~/workspace && git push
```

Flux will reconcile `infra` kustomization (Pushgateway) automatically. VM images pick up the new bootstrap secret on next VM provision.

---

## Non-goals / Future work

- Migrating existing hooks (check-goals, retrieve-context, etc.) to workspace `run.sh` files — incremental, as touched
- Grafana dashboard for `agent_goals_total` — follow-on task
- write-vault on VMs requires `WORKSPACE` pointing to a valid git clone; first vault push may take ~10s for initial clone (acceptable for async stage)
