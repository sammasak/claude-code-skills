# Forge — Company OS Design

**Date:** 2026-03-21
**Status:** Approved
**URL:** forge.sammasak.dev

---

## Overview

Forge is a "Company OS" for vibe-coding businesses. It combines:

- **ICM-structured company documentation** (Obsidian-like, git-backed) — company mission, ways of working, tech stack
- **Configurable kanban boards** — each project defines its own workflow columns
- **Agent-per-column automation** — moving a ticket to a column triggers a company-defined coding agent (claude-worker VM)
- **NATS JetStream queue** — durable, backpressure-aware dispatch preventing pool exhaustion

Doable (doable.sammasak.dev) remains the one-shot "vibe coding" product. Forge is for sustained company building: you define the company, break work into tickets, and coding agents do the building.

---

## Entity Hierarchy

```
Company
├── slug, name, github_repo_url (ICM docs)
└── Projects[]
    ├── slug, name
    └── WorkflowColumns[]   ← ordered, fully configurable
        ├── name, position
        ├── agent_config?   ← JSON: goal_template + vm overrides
        └── Tickets[]
            ├── title, description, position (fractional indexing)
            ├── workspace_name?   ← active VM
            └── AgentRuns[]
                ├── workspace_name, status, goal
                └── column_id     ← which column triggered
```

### Default columns for new projects

| Position | Name | Agent |
|----------|------|-------|
| 1 | Backlog | none |
| 2 | Ideation | research + enrich template |
| 3 | In Progress | build template |
| 4 | Review | QA/review template |
| 5 | Done | none |

All columns are fully renameable, reorderable, addable, deletable.

---

## Data Model (Postgres)

```sql
-- Companies
CREATE TABLE companies (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT UNIQUE NOT NULL,          -- URL-safe name
    name        TEXT NOT NULL,
    github_repo_url TEXT,                      -- ICM docs repo
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Projects
CREATE TABLE projects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    slug        TEXT NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(company_id, slug)
);

-- Workflow Columns
CREATE TABLE workflow_columns (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    position    INT NOT NULL,
    agent_config JSONB,                        -- null = no agent
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Tickets
CREATE TABLE tickets (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id   UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    column_id    UUID NOT NULL REFERENCES workflow_columns(id),
    title        TEXT NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    position     FLOAT NOT NULL DEFAULT 0,    -- fractional indexing
    workspace_name TEXT,                       -- active VM (null when no agent running)
    created_at   TIMESTAMPTZ DEFAULT now(),
    updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Agent Runs
CREATE TABLE agent_runs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id      UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    column_id      UUID NOT NULL REFERENCES workflow_columns(id),
    workspace_name TEXT,
    status         TEXT NOT NULL DEFAULT 'queued',  -- queued|running|done|failed
    goal           TEXT NOT NULL,
    error_message  TEXT,
    queued_at      TIMESTAMPTZ DEFAULT now(),
    started_at     TIMESTAMPTZ,
    ended_at       TIMESTAMPTZ
);
```

### `agent_config` JSONB shape

```json
{
  "goal_template": "You are a senior engineer at {{company.name}}.\n\nFirst, read the company context:\ngit clone {{company.github_repo_url}} company-context && cat company-context/CLAUDE.md\n\n## Ticket\n**{{ticket.title}}**\n\n{{ticket.description}}\n\nBuild this.",
  "instancetype_name": "workstation-standard"
}
```

Available template placeholders:

| Placeholder | Value |
|-------------|-------|
| `{{ticket.title}}` | Ticket title |
| `{{ticket.description}}` | Ticket description |
| `{{company.name}}` | Company name |
| `{{company.github_repo_url}}` | ICM docs git repo URL |
| `{{project.name}}` | Project name |
| `{{column.name}}` | Destination column name |

---

## Queue Architecture — NATS JetStream

NATS JetStream replaces ad-hoc Postgres polling. It provides durable delivery, backpressure, retry, and dead-letter handling without heavyweight infrastructure.

### Why NATS JetStream

- **Purpose-built work queue**: pull consumers with ack/nack, redelivery on timeout, dead-letter stream
- **Rust support**: `async-nats` crate is mature and well-maintained
- **Lightweight**: single pod, ~50MB memory, no external storage needed for this scale
- **Dual use**: queue for dispatch + pub/sub for agent status events (SSE broadcast)
- **No broker**: unlike RabbitMQ/Kafka, NATS is trivially operable in k8s

### Streams and Subjects

```
Stream: FORGE_DISPATCH
  Subjects: forge.dispatch.*
  Retention: WorkQueue (messages deleted on ack)
  MaxDeliver: 5  (retry up to 5 times)
  AckWait: 120s  (nack if dispatch takes >2min)

Stream: FORGE_EVENTS
  Subjects: forge.events.*
  Retention: Limits (last 1000 messages per subject)
  Use: agent status updates → SSE broadcast to frontend
```

### Dispatch Consumer

```
Consumer: forge-dispatcher (pull, durable)
  FilterSubject: forge.dispatch.*
  MaxAckPending: POOL_SIZE  ← limits concurrent dispatches to pool capacity
  AckWait: 120s
```

The `MaxAckPending = pool_size` is the key backpressure mechanism — the dispatcher can only pull as many messages as there are pool VMs. If the pool is full, messages stay in the queue.

### Dispatch Flow

```
1. PUT /tickets/:id/move { column_id, position }
      │
      ▼
2. forge-api (atomic):
   a. UPDATE tickets SET column_id = ?, position = ?
   b. INSERT agent_runs (status='queued', goal=rendered)
   c. PUBLISH forge.dispatch.{run_id} → NATS JetStream
   d. Return 200 immediately
      │
      ▼
3. Dispatcher worker (forge-api background task):
   a. Pull message from FORGE_DISPATCH consumer
   b. POST workstation-api /api/v1/workspaces (goal, display_name, etc.)
   c. On success: UPDATE agent_runs SET status='running', workspace_name=?
                  ACK message
   d. On pool exhausted (409): NACK with 30s delay → retries automatically
   e. On hard error (400): UPDATE status='failed', ACK (don't retry)
      │
      ▼
4. Status monitor (forge-api background task, every 15s):
   a. SELECT * FROM agent_runs WHERE status='running'
   b. GET workstation-api /api/v1/workspaces/:name per run
   c. If VM halted (runStrategy=Halted): UPDATE status='done', ended_at=now()
   d. If VM not found or status='Error': UPDATE status='failed'
   e. PUBLISH forge.events.{ticket_id} → broadcasts to SSE subscribers
```

### Dead-letter handling

After 5 failed delivery attempts, NATS moves the message to a dead-letter subject `forge.dispatch.dead`. forge-api monitors this and marks the AgentRun as `failed` with the error surfaced in the UI.

---

## API Design (forge-api — Rust Axum)

### Companies
```
POST   /api/v1/companies                                → 201 CompanyResponse
GET    /api/v1/companies                                → 200 Vec<CompanyResponse>
GET    /api/v1/companies/:slug                          → 200 CompanyResponse
PATCH  /api/v1/companies/:slug                          → 200 CompanyResponse
DELETE /api/v1/companies/:slug                          → 204
```

### Projects
```
POST   /api/v1/companies/:slug/projects                 → 201 ProjectResponse (+ default columns)
GET    /api/v1/companies/:slug/projects                 → 200 Vec<ProjectResponse>
GET    /api/v1/companies/:slug/projects/:project_slug   → 200 ProjectBoardResponse
DELETE /api/v1/companies/:slug/projects/:project_slug   → 204
```

`ProjectBoardResponse` includes all columns and tickets — single fetch for the kanban board.

### Columns
```
GET    /api/v1/projects/:id/columns                     → 200 Vec<ColumnResponse>
POST   /api/v1/projects/:id/columns                     → 201 ColumnResponse
PATCH  /api/v1/projects/:id/columns/:col_id             → 200 ColumnResponse
DELETE /api/v1/projects/:id/columns/:col_id             → 204
PUT    /api/v1/projects/:id/columns/reorder             → { column_ids: [uuid] } → 200
```

### Tickets
```
POST   /api/v1/columns/:col_id/tickets                  → 201 TicketResponse
PATCH  /api/v1/tickets/:id                              → 200 TicketResponse
PUT    /api/v1/tickets/:id/move                         → { column_id, position } → 200
DELETE /api/v1/tickets/:id                              → 204
```

`PUT /tickets/:id/move` is the dispatch trigger. Returns immediately after enqueuing.

### Agent Runs
```
GET    /api/v1/tickets/:id/runs                         → 200 Vec<AgentRunResponse>
GET    /api/v1/runs/:id                                 → 200 AgentRunResponse
GET    /api/v1/runs/:id/events                          → SSE (proxies workstation-api events)
```

### Fleet / Queue health
```
GET    /api/v1/queue/status                             → { queued, running, pool_capacity }
GET    /healthz
GET    /metrics
```

---

## Frontend (SvelteKit — forge.sammasak.dev)

### Routes

```
/                                    ← landing: list companies, create CTA
/[company]                           ← company home: projects list + ICM repo link
/[company]/[project]                 ← MAIN VIEW: kanban board
/[company]/[project]/tickets/[id]    ← ticket detail: description, agent run history, live log
/[company]/settings                  ← company settings: name, github_repo_url
/[company]/[project]/settings        ← project settings: column editor + agent_config templates
```

### Kanban Board (`/[company]/[project]`)

- Horizontal scrollable columns
- Drag-and-drop via `svelte-dnd-action`
- Column header: name + agent icon (if `agent_config` set) + ticket count
- Ticket card: title, status badge (queued/running/done/failed) for latest run
- Dragging to agent-enabled column: confirmation modal *"Start [Ideation] agent on this ticket?"*
- Real-time ticket status updates via SSE subscription to `forge.events.*`

### Ticket Detail (`/tickets/[id]`)

- Editable title + markdown description
- Agent run history timeline: column name, status, timestamp, rendered goal preview
- Active run: live SSE log from workstation-api (same iframe/stream pattern as doable)
- Preview URL link when VM has `preview_url`

### Project Settings (`/[project]/settings`)

- Column manager: drag to reorder, add/rename/delete
- Per-column agent config:
  - Toggle: "Trigger agent on ticket arrival"
  - Goal template editor with `{{placeholder}}` syntax hints
  - instancetype selector (workstation-standard / workstation-large)
  - "Test with sample ticket" dry-run: shows rendered goal without dispatching

---

## Deployment

```
Namespace: forge
├── nats            (nats:2.10-alpine, JetStream enabled, 1Gi PVC)
├── postgres        (postgres:16-alpine, 10Gi PVC)
├── forge-api       (Rust Axum, port 8080)
│   └── env: DATABASE_URL, NATS_URL, WORKSTATION_API_URL
└── forge-ui        (SvelteKit adapter-node, port 3000)

Ingress:
  forge.sammasak.dev           → forge-ui:3000
  forge.sammasak.dev/api       → forge-api:8080

Internal calls:
  forge-api → workstation-api.workstations.svc.cluster.local:8080
  forge-api → nats.forge.svc.cluster.local:4222
```

GitOps:
- `~/homelab-gitops/apps/forge/` — Flux Kustomization
- Two new GitHub repos: `sammasak/forge-api`, `sammasak/forge-ui`

---

## New Repos

| Repo | Description |
|------|-------------|
| `sammasak/forge-api` | Rust Axum service: companies, projects, tickets, dispatch, NATS consumer |
| `sammasak/forge-ui` | SvelteKit frontend: kanban board, ticket detail, settings |

workstation-api (`sammasak/workstation-api`) is called as an external service — **no changes needed**.

---

## Key Design Decisions

1. **Agents do not auto-advance tickets** — human always reviews and drags to next column. This keeps humans in the loop and ensures review agents run intentionally.
2. **NATS MaxAckPending = pool_size** — natural backpressure, no custom throttling code needed.
3. **forge-api is the orchestration layer** — frontend stays thin (display + drag intent), forge-api owns all business logic.
4. **ICM docs via git clone** — company context is loaded by the agent via `git clone` in the goal preamble, exactly matching the existing `repo_url` pattern in workstation-api.
5. **All column agents are VMs for now** — `agent_config` schema includes a `tier` field (`"vm"`) to enable lighter-weight agents later without migration.
6. **Fractional indexing for ticket position** — avoids bulk position updates on every reorder.
