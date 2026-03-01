---
name: spawn-openfang-worker
description: "Use when the central OpenFang instance needs to spawn and manage subordinate OpenFang worker VMs via the workspace-api REST API. Guides KubeVirt VM creation, skill injection, A2A task delegation, and teardown."
allowed-tools: Bash, Read, Grep, Glob
---

# Spawn OpenFang Worker

Create a new OpenFang sub-instance as a KubeVirt VM via the workspace-api.
The worker receives skills from the central repo and a task assignment.

## Parameters

- **name**: unique worker identifier (RFC 1123 DNS label)
- **skills**: list of skill names to inject after boot
- **task**: natural language task description to assign
- **model**: LLM model to use (default: `claude-sonnet-4-20250514`)
- **instancetype**: KubeVirt instancetype (default: `openfang-agent`)

## Procedure

### 1. Create the worker via workspace-api

```bash
HTTP_CODE=$(curl -s -o /tmp/ws-response.json -w '%{http_code}' -X POST http://workstation-api.workstations:8080/api/v1/workspaces \
  -H "Content-Type: application/json" \
  -d '{
    "name": "worker-{name}",
    "containerDiskImage": "registry.sammasak.dev/agents/openfang-agent:latest",
    "bootstrapSecretName": "openfang-worker-bootstrap",
    "runStrategy": "Always",
    "instancetypeName": "{instancetype}",
    "workspaceStorage": "5Gi",
    "idleHaltAfterMinutes": 60,
    "serviceType": "ClusterIP",
    "labels": {
      "managed-by": "openfang-central",
      "openfang-role": "worker"
    }
  }')

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "ERROR: Workspace creation failed with HTTP $HTTP_CODE"
  cat /tmp/ws-response.json
  exit 1
fi
RESPONSE=$(cat /tmp/ws-response.json)
```

### 2. Poll for readiness

Wait until `vmStatus` is `"Running"`. Poll every 10 seconds, timeout after 5 minutes.

```bash
curl -s http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name}
```

Check the response for `vmStatus` field. Example poll loop:

```bash
TIMEOUT=300
INTERVAL=10
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  STATUS=$(curl -s http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name} \
    | jq -r '.vmStatus')
  if [ "$STATUS" = "Running" ]; then
    echo "Worker is running"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [ "$STATUS" != "Running" ]; then
  echo "ERROR: Worker did not reach Running state within ${TIMEOUT}s"
  # Clean up the failed workspace
  curl -s -X DELETE http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name}
  exit 1
fi
```

### 3. Get worker IP

Extract `ipAddress` from the workspace status response:

```bash
IP=$(curl -s http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name} \
  | jq -r '.ipAddress')
```

### 4. Discover worker A2A endpoint

Verify the worker's OpenFang agent is ready by polling its agent card. The VM may be Running at the KubeVirt level before the OpenFang agent on port 4200 is fully initialized.

```bash
TIMEOUT=120
INTERVAL=5
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  CARD=$(curl -s --connect-timeout 3 http://${IP}:4200/.well-known/agent.json 2>/dev/null)
  if echo "$CARD" | jq -e '.name' > /dev/null 2>&1; then
    echo "Worker agent is ready"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

if ! echo "$CARD" | jq -e '.name' > /dev/null 2>&1; then
  echo "ERROR: Worker agent did not become ready within ${TIMEOUT}s"
  curl -s -X DELETE http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name}
  exit 1
fi
```

The agent card confirms A2A protocol support and lists available capabilities.

### 5. Inject skills

For each skill in the `skills` list, POST to the worker's skill creation endpoint. Read skill content from the central skill repo before sending.

Example: inject a `kubernetes-query` skill:

```bash
curl -s -X POST http://${IP}:4200/api/skills/create \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kubernetes-query",
    "description": "Query Kubernetes cluster resources",
    "instructions": "Use kubectl to query cluster state. Supports get, describe, and logs commands.",
    "tools": ["shell_exec"]
  }'
```

Repeat for every skill the worker needs. Verify each POST returns HTTP 200/201 before proceeding to the next skill.

> **NOTE:** The exact JSON schema for skill creation depends on the OpenFang version running in the worker image. The endpoint pattern is `POST /api/skills/create` with at minimum `name`, `description`, `instructions`, and `tools` fields. Consult the OpenFang API documentation for the deployed version if the schema has changed.

### 6. Send task via A2A

Generate identifiers and submit the task to the worker using the A2A protocol:

```bash
# Generate task ID (ULID preferred, UUID fallback)
TASK_ID=$(python3 -c "import ulid; print(ulid.new().str)" 2>/dev/null || uuidgen)
SESSION_ID=$(python3 -c "import ulid; print(ulid.new().str)" 2>/dev/null || uuidgen)

curl -s -X POST http://${IP}:4200/a2a/tasks/send \
  -H "Content-Type: application/json" \
  -d '{
    "id": "'"${TASK_ID}"'",
    "session_id": "'"${SESSION_ID}"'",
    "status": {"state": "submitted"},
    "messages": [
      {
        "role": "user",
        "parts": [{"type": "text", "text": "{task}"}]
      }
    ]
  }'
```

### 7. Monitor task completion

Poll until `status.state` is `"completed"` or `"failed"`. Poll every 15 seconds with a configurable timeout.

```bash
TASK_TIMEOUT=600  # Adjust based on expected task duration
INTERVAL=15
ELAPSED=0
while [ "$ELAPSED" -lt "$TASK_TIMEOUT" ]; do
  RESULT=$(curl -s http://${IP}:4200/a2a/tasks/${TASK_ID})
  STATE=$(echo "$RESULT" | jq -r '.status.state')
  if [ "$STATE" = "completed" ] || [ "$STATE" = "failed" ]; then
    echo "Task finished with state: $STATE"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [ "$STATE" != "completed" ] && [ "$STATE" != "failed" ]; then
  echo "WARNING: Task did not finish within ${TASK_TIMEOUT}s, proceeding to teardown"
fi
```

Collect the task result from `$RESULT`. If the task failed, capture the error details from the response before teardown.

### 8. Collect results and tear down

After retrieving the task results, delete the worker VM:

```bash
curl -s -X DELETE http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name}
```

Owner-reference cascade on WorkspaceClaim deletion automatically cleans up the VM, PVC, and Service.

## Error Handling

Common failure modes and how to handle them:

- **409 Conflict on workspace creation (Step 1):** A workspace named `worker-{name}` already exists. Either choose a different name, or delete the existing workspace first with `curl -s -X DELETE http://workstation-api.workstations:8080/api/v1/workspaces/worker-{name}` and retry.
- **400 Bad Request on workspace creation (Step 1):** The request payload is malformed or contains invalid values (e.g., invalid instancetype name, bad DNS label in name). Validate that `{name}` is a valid RFC 1123 DNS label (lowercase alphanumeric and hyphens, max 63 characters) and that `{instancetype}` exists in the cluster.
- **VM stuck in non-Running state (Step 2):** The timeout handler will clean up automatically. Check workspace-api logs and KubeVirt events (`kubectl get vmi -n workstations`) for root cause before retrying.
- **Agent not ready after VM is Running (Step 4):** The timeout handler will clean up automatically. This can happen if the bootstrap secret is missing or misconfigured. Verify the secret exists: `kubectl get secret openfang-worker-bootstrap -n workstations`.
- **Skill injection returns 4xx/5xx (Step 5):** Log the error response body. Common causes: invalid skill schema, agent not fully initialized. Retry once after a short delay before failing.
- **DELETE fails during teardown (Step 8):** Log the error and retry. If the workspace-api is unreachable, the worker VM will still auto-halt after `idleHaltAfterMinutes`. For stuck resources, use `kubectl delete workspaceclaim worker-{name} -n workstations` as a fallback.
- **General guidance:** Always capture HTTP status codes from curl (`-w '%{http_code}'`) to distinguish between success and failure. On any unrecoverable error, ensure the workspace is deleted to avoid resource leaks.

## Notes

- Workers use a shared bootstrap secret (`openfang-worker-bootstrap`) for initial configuration
- Worker VMs auto-halt after `idleHaltAfterMinutes` if the central instance does not heartbeat
- Owner-reference cascade on WorkspaceClaim deletion cleans up VM + PVC + Service
- Workers use ClusterIP services (no MetalLB IP needed)
- Worker DNS: `worker-{name}-ssh.workstations.svc.cluster.local`
- Workers are tagged with `managed-by=openfang-central` for identification and bulk operations
- Use `ipAddress` from workspace status to connect to OpenFang API on port 4200
- The workspace-api runs in the `workstations` namespace and is accessible cluster-internally
- If a worker is no longer needed but the task is incomplete, delete the workspace to reclaim resources
