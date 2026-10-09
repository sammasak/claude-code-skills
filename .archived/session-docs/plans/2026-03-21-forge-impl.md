# Forge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build Forge — a Company OS combining ICM-structured docs, configurable kanban boards, and NATS-queued coding agent dispatch — deployed at forge.sammasak.dev.

**Architecture:** Two new repos: `forge-api` (Rust Axum + Postgres + NATS JetStream) and `forge-ui` (SvelteKit). forge-api owns all business logic including the kanban state machine and agent dispatch. It calls the existing `workstation-api` to provision VMs. A NATS JetStream work queue provides backpressure so the pool is never overwhelmed.

**Tech Stack:** Rust (axum, sqlx, async-nats, uuid, tokio), Postgres 16, NATS 2.10 JetStream, SvelteKit 2 + Svelte 5, svelte-dnd-action, adapter-node, buildah for images, Flux GitOps for deploy.

**Reference design:** `/home/lukas/claude-code-skills/docs/plans/2026-03-21-forge-design.md`
**Existing pattern to follow:** `/home/lukas/workstation-api/` — same Axum structure, error handling, OpenAPI, metrics.

---

## Phase 1: forge-api — Project Scaffold

### Task 1: Create Rust project and Cargo.toml

**Files:**
- Create: `~/forge-api/Cargo.toml`
- Create: `~/forge-api/src/main.rs`
- Create: `~/forge-api/src/lib.rs`
- Create: `~/forge-api/flake.nix`
- Create: `~/forge-api/CLAUDE.md`
- Create: `~/forge-api/justfile`

**Step 1: Init the project**

```bash
cd ~ && cargo new forge-api && cd forge-api
git init && git branch -m main
```

**Step 2: Write Cargo.toml**

```toml
[package]
name = "forge-api"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "forge-api"
path = "src/main.rs"

[dependencies]
axum = { version = "0.8", features = ["macros"] }
tokio = { version = "1", features = ["full"] }
tower-http = { version = "0.6", features = ["cors", "trace"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid", "chrono", "json"] }
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
async-nats = "0.37"
reqwest = { version = "0.12", features = ["json"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
thiserror = "2"
anyhow = "1"
dotenvy = "0.15"
utoipa = { version = "5", features = ["axum_extras", "uuid", "chrono"] }
utoipa-swagger-ui = { version = "8", features = ["axum"] }
prometheus = { version = "0.13", features = ["process"] }
axum-prometheus = "0.7"

[dev-dependencies]
axum-test = "16"
tokio = { version = "1", features = ["full"] }
```

**Step 3: Write flake.nix** (gives cargo, sqlx-cli, nats-server for tests)

```nix
{
  description = "forge-api";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            rustup cargo-watch sqlx-cli postgresql_16 nats-server natscli
          ];
          RUST_LOG = "forge_api=debug,tower_http=info";
          DATABASE_URL = "postgresql://forge@localhost/forge";
          NATS_URL = "nats://localhost:4222";
        };
      });
}
```

**Step 4: Write justfile**

```makefile
build:
    cargo build --release

test:
    cargo test

lint:
    cargo fmt --check && cargo clippy -- -D warnings

fmt:
    cargo fmt

migrate:
    sqlx migrate run

db-reset:
    sqlx database drop -y && sqlx database create && sqlx migrate run

release:
    cargo build --release
    buildah build --isolation=chroot -t registry.sammasak.dev/lab/forge-api:latest .
    buildah push --authfile ~/.config/containers/auth.json registry.sammasak.dev/lab/forge-api:latest

deploy:
    kubectl rollout restart deployment/forge-api -n forge
```

**Step 5: Write minimal CLAUDE.md**

```markdown
# forge-api

Rust Axum HTTP service. Manages companies, projects, kanban columns, tickets, and agent dispatch.

## Build
`just build` — release build
`just test` — run tests
`just lint` — clippy + fmt check
`just migrate` — run sqlx migrations

## Dev
`nix develop` — enter dev shell with cargo, sqlx-cli, postgres

## Env vars
DATABASE_URL=postgresql://forge@localhost/forge
NATS_URL=nats://localhost:4222
WORKSTATION_API_URL=http://workstation-api.workstations.svc.cluster.local:8080
BIND_ADDR=0.0.0.0:8080

## Architecture
See docs/plans/2026-03-21-forge-design.md in claude-code-skills repo.
```

**Step 6: Commit**

```bash
git add . && git commit -m "chore: scaffold forge-api project"
```

---

### Task 2: Error handling and AppState

**Files:**
- Create: `~/forge-api/src/error.rs`
- Create: `~/forge-api/src/state.rs`
- Create: `~/forge-api/src/lib.rs`

**Step 1: Write src/error.rs**

```rust
use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("conflict: {0}")]
    Conflict(String),
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("nats error: {0}")]
    Nats(String),
    #[error("upstream error: {0}")]
    Upstream(String),
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
    message: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error, message) = match &self {
            ApiError::NotFound(m) => (StatusCode::NOT_FOUND, "not found", m.clone()),
            ApiError::BadRequest(m) => (StatusCode::BAD_REQUEST, "bad request", m.clone()),
            ApiError::Conflict(m) => (StatusCode::CONFLICT, "conflict", m.clone()),
            ApiError::Database(e) => {
                if let sqlx::Error::RowNotFound = e {
                    (StatusCode::NOT_FOUND, "not found", "resource not found".into())
                } else {
                    tracing::error!(error = %e, "database error");
                    (StatusCode::INTERNAL_SERVER_ERROR, "database error", e.to_string())
                }
            }
            ApiError::Nats(m) => {
                tracing::error!(error = %m, "nats error");
                (StatusCode::INTERNAL_SERVER_ERROR, "queue error", m.clone())
            }
            ApiError::Upstream(m) => {
                tracing::error!(error = %m, "upstream error");
                (StatusCode::BAD_GATEWAY, "upstream error", m.clone())
            }
        };
        (status, Json(ErrorBody { error: error.into(), message })).into_response()
    }
}

pub type Result<T> = std::result::Result<T, ApiError>;
```

**Step 2: Write src/state.rs**

```rust
use sqlx::PgPool;
use async_nats::Client as NatsClient;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub nats: NatsClient,
    pub workstation_api_url: String,
    pub workstation_namespace: String,
    pub bootstrap_secret_name: String,
    pub container_disk_image: String,
}

impl AppState {
    pub fn new(
        db: PgPool,
        nats: NatsClient,
        workstation_api_url: String,
        workstation_namespace: String,
        bootstrap_secret_name: String,
        container_disk_image: String,
    ) -> Arc<Self> {
        Arc::new(Self {
            db,
            nats,
            workstation_api_url,
            workstation_namespace,
            bootstrap_secret_name,
            container_disk_image,
        })
    }
}
```

**Step 3: Write src/lib.rs** (router builder, initially just health)

```rust
mod error;
mod state;

pub use error::{ApiError, Result};
pub use state::AppState;

use axum::{routing::get, Router};
use std::sync::Arc;
use tower_http::{cors::CorsLayer, trace::TraceLayer};

pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
```

**Step 4: Write src/main.rs**

```rust
use forge_api::{build_router, AppState};
use sqlx::postgres::PgPoolOptions;
use std::env;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            env::var("RUST_LOG").unwrap_or_else(|_| "forge_api=info,tower_http=info".into()),
        )
        .init();

    dotenvy::dotenv().ok();

    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL required");
    let nats_url = env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let workstation_api_url = env::var("WORKSTATION_API_URL")
        .unwrap_or_else(|_| "http://workstation-api.workstations.svc.cluster.local:8080".into());
    let workstation_namespace =
        env::var("WORKSTATION_NAMESPACE").unwrap_or_else(|_| "workstations".into());
    let bootstrap_secret_name =
        env::var("BOOTSTRAP_SECRET_NAME").unwrap_or_else(|_| "claude-worker-bootstrap".into());
    let container_disk_image = env::var("CONTAINER_DISK_IMAGE")
        .unwrap_or_else(|_| "registry.sammasak.dev/agents/claude-worker:latest".into());
    let bind_addr = env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".into());

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;
    sqlx::migrate!("./migrations").run(&db).await?;

    let nats = async_nats::connect(&nats_url).await?;

    let state = AppState::new(
        db,
        nats,
        workstation_api_url,
        workstation_namespace,
        bootstrap_secret_name,
        container_disk_image,
    );

    let app = build_router(state);
    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;
    tracing::info!(addr = %bind_addr, "forge-api listening");
    axum::serve(listener, app).await?;
    Ok(())
}
```

**Step 5: Verify it compiles**

```bash
nix develop --command cargo build
```
Expected: compiles with no errors.

**Step 6: Commit**

```bash
git add . && git commit -m "feat: AppState, error handling, minimal router"
```

---

### Task 3: Postgres migrations

**Files:**
- Create: `~/forge-api/migrations/001_initial.sql`

**Step 1: Create migrations directory and initial migration**

```bash
mkdir -p migrations
```

Write `migrations/001_initial.sql`:

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE companies (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    github_repo_url TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    slug        TEXT NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, slug)
);

CREATE TABLE workflow_columns (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id   UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    position     INT NOT NULL DEFAULT 0,
    agent_config JSONB,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tickets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id     UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    column_id      UUID NOT NULL REFERENCES workflow_columns(id),
    title          TEXT NOT NULL,
    description    TEXT NOT NULL DEFAULT '',
    position       FLOAT NOT NULL DEFAULT 0,
    workspace_name TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE agent_runs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id      UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    column_id      UUID NOT NULL REFERENCES workflow_columns(id),
    workspace_name TEXT,
    status         TEXT NOT NULL DEFAULT 'queued'
                       CHECK (status IN ('queued','running','done','failed')),
    goal           TEXT NOT NULL,
    error_message  TEXT,
    queued_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at     TIMESTAMPTZ,
    ended_at       TIMESTAMPTZ
);

CREATE INDEX ON projects(company_id);
CREATE INDEX ON workflow_columns(project_id);
CREATE INDEX ON tickets(project_id);
CREATE INDEX ON tickets(column_id);
CREATE INDEX ON agent_runs(ticket_id);
CREATE INDEX ON agent_runs(status) WHERE status IN ('queued','running');
```

**Step 2: Run migrations against local Postgres**

```bash
# Start postgres locally if needed
nix develop --command bash -c "
  createuser -s forge 2>/dev/null || true
  createdb forge 2>/dev/null || true
  sqlx migrate run
"
```
Expected: `1/applied 001_initial.sql`

**Step 3: Prepare sqlx offline cache** (so CI compiles without DB)

```bash
nix develop --command cargo sqlx prepare
```

**Step 4: Commit**

```bash
git add migrations/ .sqlx/ && git commit -m "feat: initial postgres migrations"
```

---

## Phase 2: Companies and Projects CRUD

### Task 4: Company handlers

**Files:**
- Create: `~/forge-api/src/handlers/companies.rs`
- Modify: `~/forge-api/src/lib.rs`

**Step 1: Write failing test**

Create `~/forge-api/tests/companies.rs`:

```rust
use axum_test::TestServer;
use forge_api::build_router_for_test;
use serde_json::json;

#[sqlx::test]
async fn test_create_and_get_company(pool: sqlx::PgPool) {
    let server = TestServer::new(build_router_for_test(pool).await).unwrap();

    let res = server.post("/api/v1/companies")
        .json(&json!({ "name": "Acme Corp", "slug": "acme" }))
        .await;
    assert_eq!(res.status_code(), 201);
    let body: serde_json::Value = res.json();
    assert_eq!(body["slug"], "acme");
    assert_eq!(body["name"], "Acme Corp");

    let res = server.get("/api/v1/companies/acme").await;
    assert_eq!(res.status_code(), 200);
    assert_eq!(res.json::<serde_json::Value>()["name"], "Acme Corp");
}

#[sqlx::test]
async fn test_duplicate_slug_returns_409(pool: sqlx::PgPool) {
    let server = TestServer::new(build_router_for_test(pool).await).unwrap();
    let body = json!({ "name": "Acme", "slug": "acme" });
    server.post("/api/v1/companies").json(&body).await;
    let res = server.post("/api/v1/companies").json(&body).await;
    assert_eq!(res.status_code(), 409);
}
```

**Step 2: Run test to verify it fails**

```bash
nix develop --command cargo test companies -- --nocapture
```
Expected: compile error — `build_router_for_test` not defined.

**Step 3: Implement companies handler**

Create `~/forge-api/src/handlers/companies.rs`:

```rust
use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

use crate::{ApiError, AppState, Result};

#[derive(Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct CompanyResponse {
    pub id: Uuid,
    pub slug: String,
    pub name: String,
    pub github_repo_url: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateCompanyRequest {
    pub slug: String,
    pub name: String,
    pub github_repo_url: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatchCompanyRequest {
    pub name: Option<String>,
    pub github_repo_url: Option<String>,
}

pub async fn create_company(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateCompanyRequest>,
) -> Result<(StatusCode, Json<CompanyResponse>)> {
    validate_slug(&req.slug)?;
    let row = sqlx::query_as!(
        CompanyResponse,
        r#"INSERT INTO companies (slug, name, github_repo_url)
           VALUES ($1, $2, $3)
           RETURNING id, slug, name, github_repo_url, created_at, updated_at"#,
        req.slug,
        req.name,
        req.github_repo_url,
    )
    .fetch_one(&state.db)
    .await
    .map_err(|e| match &e {
        sqlx::Error::Database(db) if db.constraint() == Some("companies_slug_key") => {
            ApiError::Conflict(format!("slug '{}' already taken", req.slug))
        }
        _ => ApiError::Database(e),
    })?;
    Ok((StatusCode::CREATED, Json(row)))
}

pub async fn list_companies(
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<CompanyResponse>>> {
    let rows = sqlx::query_as!(
        CompanyResponse,
        "SELECT id, slug, name, github_repo_url, created_at, updated_at FROM companies ORDER BY created_at"
    )
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

pub async fn get_company(
    State(state): State<Arc<AppState>>,
    Path(slug): Path<String>,
) -> Result<Json<CompanyResponse>> {
    let row = sqlx::query_as!(
        CompanyResponse,
        "SELECT id, slug, name, github_repo_url, created_at, updated_at FROM companies WHERE slug = $1",
        slug
    )
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

pub async fn patch_company(
    State(state): State<Arc<AppState>>,
    Path(slug): Path<String>,
    Json(req): Json<PatchCompanyRequest>,
) -> Result<Json<CompanyResponse>> {
    let row = sqlx::query_as!(
        CompanyResponse,
        r#"UPDATE companies SET
             name = COALESCE($2, name),
             github_repo_url = COALESCE($3, github_repo_url),
             updated_at = now()
           WHERE slug = $1
           RETURNING id, slug, name, github_repo_url, created_at, updated_at"#,
        slug,
        req.name,
        req.github_repo_url,
    )
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

pub async fn delete_company(
    State(state): State<Arc<AppState>>,
    Path(slug): Path<String>,
) -> Result<StatusCode> {
    sqlx::query!("DELETE FROM companies WHERE slug = $1", slug)
        .execute(&state.db)
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

fn validate_slug(slug: &str) -> Result<()> {
    if slug.is_empty() || slug.len() > 63 {
        return Err(ApiError::BadRequest("slug must be 1-63 characters".into()));
    }
    if !slug.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-') {
        return Err(ApiError::BadRequest(
            "slug must contain only lowercase letters, digits, hyphens".into(),
        ));
    }
    Ok(())
}
```

**Step 4: Wire into lib.rs and add test helper**

```rust
// src/lib.rs additions:
pub mod handlers;

use handlers::companies::*;
use axum::routing::{delete, get, patch, post};

pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .route("/api/v1/companies", get(list_companies).post(create_company))
        .route("/api/v1/companies/:slug", get(get_company).patch(patch_company).delete(delete_company))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

// Test helper — uses test PgPool (no NATS needed for unit tests)
#[cfg(test)]
pub async fn build_router_for_test(pool: sqlx::PgPool) -> Router {
    use async_nats::ConnectOptions;
    // Mock NATS — connect attempts will fail gracefully in unit tests
    let nats = async_nats::connect("nats://localhost:4222").await
        .unwrap_or_else(|_| panic!("start nats-server for tests: nix develop --command nats-server -js &"));
    let state = AppState::new(
        pool,
        nats,
        "http://workstation-api:8080".into(),
        "workstations".into(),
        "claude-worker-bootstrap".into(),
        "registry.sammasak.dev/agents/claude-worker:latest".into(),
    );
    build_router(state)
}
```

**Step 5: Run tests**

```bash
nix develop --command bash -c "nats-server -js &>/tmp/nats.log & sleep 1 && cargo test companies"
```
Expected: all company tests pass.

**Step 6: Commit**

```bash
git add . && git commit -m "feat: company CRUD endpoints"
```

---

### Task 5: Project handlers

**Files:**
- Create: `~/forge-api/src/handlers/projects.rs`

Follow the same TDD pattern as Task 4. Key behavior to test:

1. `POST /api/v1/companies/:slug/projects` creates project AND 5 default columns (Backlog, Ideation, In Progress, Review, Done — only In Progress and Review have `agent_config`)
2. `GET /api/v1/companies/:slug/projects/:project_slug` returns `ProjectBoardResponse` with columns + tickets nested
3. Duplicate slug within same company returns 409

**Default columns to insert on project creation:**

```rust
const DEFAULT_COLUMNS: &[(&str, bool)] = &[
    ("Backlog", false),
    ("Ideation", true),
    ("In Progress", true),
    ("Review", true),
    ("Done", false),
];

const IDEATION_TEMPLATE: &str = r#"You are a product researcher at {{company.name}}.

Read the company context:
git clone {{company.github_repo_url}} .company-context 2>/dev/null && cat .company-context/CLAUDE.md || echo "No company context found"

## Ticket to enrich
**{{ticket.title}}**

{{ticket.description}}

Research this topic thoroughly. Produce:
1. A concise problem statement
2. 3-5 key technical approaches
3. Recommended approach with rationale
4. Updated ticket description with this research

Output as markdown."#;

const BUILD_TEMPLATE: &str = r#"You are a senior engineer at {{company.name}}.

Read the company context:
git clone {{company.github_repo_url}} .company-context 2>/dev/null && cat .company-context/CLAUDE.md || echo "No company context"

## Ticket
**{{ticket.title}}**

{{ticket.description}}

Build this. Deploy to the homelab when done."#;

const REVIEW_TEMPLATE: &str = r#"You are a QA engineer at {{company.name}}.

## Ticket
**{{ticket.title}}**

{{ticket.description}}

Review the implementation, run tests, check for edge cases. Report findings."#;
```

**ProjectBoardResponse shape:**

```rust
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectBoardResponse {
    pub id: Uuid,
    pub slug: String,
    pub name: String,
    pub company_id: Uuid,
    pub columns: Vec<ColumnWithTickets>,
    pub created_at: DateTime<Utc>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ColumnWithTickets {
    pub id: Uuid,
    pub name: String,
    pub position: i32,
    pub agent_config: Option<serde_json::Value>,
    pub tickets: Vec<TicketSummary>,
}

#[derive(Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct TicketSummary {
    pub id: Uuid,
    pub title: String,
    pub position: f64,
    pub workspace_name: Option<String>,
    pub latest_run_status: Option<String>,  // from agent_runs
}
```

Fetch the board in two queries: (1) columns for project, (2) tickets with latest run status via LEFT JOIN.

**Step N: Commit**
```bash
git commit -m "feat: project CRUD with default columns on creation"
```

---

### Task 6: Column handlers

**Files:**
- Create: `~/forge-api/src/handlers/columns.rs`

Test cases:
1. Add column to project
2. Rename column
3. Set/clear `agent_config`
4. Reorder columns — `PUT /api/v1/projects/:id/columns/reorder` with `{ column_ids: [uuid] }` → update `position` 0, 1, 2… for each
5. Delete column (only if no tickets; return 409 if tickets exist)

**Step N: Commit**
```bash
git commit -m "feat: column CRUD and reorder"
```

---

### Task 7: Ticket handlers (without dispatch)

**Files:**
- Create: `~/forge-api/src/handlers/tickets.rs`

Test cases:
1. Create ticket in a column
2. Edit title/description
3. Move ticket to different column (no agent_config) — just updates column_id + position
4. Move ticket to column WITH agent_config — publishes to NATS (mock NATS in test by checking AgentRun row was inserted with status='queued')
5. Delete ticket

**The move handler is the core — test it carefully:**

```rust
pub async fn move_ticket(
    State(state): State<Arc<AppState>>,
    Path(ticket_id): Path<Uuid>,
    Json(req): Json<MoveTicketRequest>,
) -> Result<Json<TicketResponse>> {
    // 1. Fetch ticket (need project_id for company lookup)
    // 2. Fetch destination column + its agent_config
    // 3. Update ticket.column_id and ticket.position
    // 4. If column has agent_config:
    //    a. Fetch company for template rendering
    //    b. Render goal template
    //    c. INSERT agent_runs (status='queued', goal=rendered)
    //    d. PUBLISH to NATS "forge.dispatch.{run_id}"
    // 5. Return updated ticket
}
```

Goal template rendering (simple string replace):

```rust
fn render_goal(template: &str, ticket: &Ticket, company: &Company, project: &Project, column: &Column) -> String {
    template
        .replace("{{ticket.title}}", &ticket.title)
        .replace("{{ticket.description}}", &ticket.description)
        .replace("{{company.name}}", &company.name)
        .replace("{{company.github_repo_url}}", company.github_repo_url.as_deref().unwrap_or(""))
        .replace("{{project.name}}", &project.name)
        .replace("{{column.name}}", &column.name)
}
```

**Step N: Commit**
```bash
git commit -m "feat: ticket CRUD and move with agent dispatch enqueue"
```

---

## Phase 3: NATS JetStream Queue

### Task 8: NATS stream setup and dispatcher

**Files:**
- Create: `~/forge-api/src/nats.rs`
- Create: `~/forge-api/src/dispatcher.rs`
- Modify: `~/forge-api/src/main.rs`

**Step 1: Write src/nats.rs** — stream/consumer provisioning

```rust
use async_nats::jetstream::{self, stream::Config as StreamConfig, consumer::pull::Config as ConsumerConfig};

pub async fn setup_jetstream(nats: &async_nats::Client) -> anyhow::Result<jetstream::Context> {
    let js = jetstream::new(nats.clone());

    // Dispatch work queue
    js.get_or_create_stream(StreamConfig {
        name: "FORGE_DISPATCH".into(),
        subjects: vec!["forge.dispatch.>".into()],
        retention: jetstream::stream::RetentionPolicy::WorkQueue,
        max_deliver: 5,
        ..Default::default()
    }).await?;

    // Events pub/sub (for SSE)
    js.get_or_create_stream(StreamConfig {
        name: "FORGE_EVENTS".into(),
        subjects: vec!["forge.events.>".into()],
        retention: jetstream::stream::RetentionPolicy::Limits,
        max_messages_per_subject: 1000,
        ..Default::default()
    }).await?;

    Ok(js)
}
```

**Step 2: Write src/dispatcher.rs** — pull consumer loop

```rust
use crate::AppState;
use std::sync::Arc;

pub async fn run_dispatcher(state: Arc<AppState>, js: async_nats::jetstream::Context) {
    let consumer = js
        .get_or_create_consumer::<async_nats::jetstream::consumer::pull::Config>(
            "FORGE_DISPATCH",
            async_nats::jetstream::consumer::pull::Config {
                durable_name: Some("forge-dispatcher".into()),
                filter_subject: "forge.dispatch.>".into(),
                max_ack_pending: get_pool_capacity(&state).await.unwrap_or(3) as i64,
                ack_wait: std::time::Duration::from_secs(120),
                ..Default::default()
            },
        )
        .await
        .expect("failed to create dispatcher consumer");

    loop {
        match consumer.fetch().max_messages(1).messages().await {
            Ok(mut messages) => {
                while let Ok(Some(msg)) = messages.next().await {
                    let state = state.clone();
                    let js = js.clone();
                    tokio::spawn(async move {
                        dispatch_message(state, js, msg).await;
                    });
                }
            }
            Err(e) => {
                tracing::error!(error = %e, "dispatcher fetch error, retrying in 5s");
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
        }
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
    }
}

async fn dispatch_message(
    state: Arc<AppState>,
    js: async_nats::jetstream::Context,
    msg: async_nats::jetstream::Message,
) {
    // 1. Parse run_id from subject "forge.dispatch.{run_id}"
    // 2. Fetch agent_run from DB
    // 3. POST workstation-api /api/v1/workspaces with rendered goal
    // 4. On success: UPDATE agent_runs SET status='running', workspace_name=?
    //    ACK message
    // 5. On 409 (pool exhausted): NAK with 30s delay
    // 6. On 4xx (bad request): UPDATE status='failed', ACK
}

async fn get_pool_capacity(state: &AppState) -> anyhow::Result<usize> {
    let url = format!("{}/api/v1/fleet/status", state.workstation_api_url);
    let res: serde_json::Value = reqwest::get(&url).await?.json().await?;
    // total pool VMs - running = available capacity, minimum 1
    let total = res["total"].as_u64().unwrap_or(3) as usize;
    let running = res["running"].as_u64().unwrap_or(0) as usize;
    Ok(total.saturating_sub(running).max(1))
}
```

**Step 3: Write src/monitor.rs** — status polling loop

```rust
pub async fn run_status_monitor(state: Arc<AppState>, js: async_nats::jetstream::Context) {
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(15)).await;
        if let Err(e) = poll_running_runs(&state, &js).await {
            tracing::error!(error = %e, "status monitor error");
        }
    }
}

async fn poll_running_runs(state: &AppState, js: &async_nats::jetstream::Context) -> anyhow::Result<()> {
    let runs = sqlx::query!(
        "SELECT id, ticket_id, workspace_name FROM agent_runs WHERE status = 'running' AND workspace_name IS NOT NULL"
    )
    .fetch_all(&state.db)
    .await?;

    for run in runs {
        let ws_name = run.workspace_name.unwrap();
        let url = format!("{}/api/v1/workspaces/{}", state.workstation_api_url, ws_name);
        match reqwest::get(&url).await {
            Ok(res) if res.status().is_success() => {
                let body: serde_json::Value = res.json().await?;
                let run_strategy = body["runStrategy"].as_str().unwrap_or("");
                if run_strategy == "Halted" {
                    sqlx::query!(
                        "UPDATE agent_runs SET status='done', ended_at=now() WHERE id=$1",
                        run.id
                    ).execute(&state.db).await?;
                    // Publish status event for SSE
                    js.publish(format!("forge.events.{}", run.ticket_id), "done".into()).await?;
                }
            }
            Ok(res) if res.status().as_u16() == 404 => {
                sqlx::query!(
                    "UPDATE agent_runs SET status='failed', error_message='VM not found', ended_at=now() WHERE id=$1",
                    run.id
                ).execute(&state.db).await?;
                js.publish(format!("forge.events.{}", run.ticket_id), "failed".into()).await?;
            }
            Err(e) => tracing::warn!(run_id=%run.id, error=%e, "status check failed"),
            _ => {}
        }
    }
    Ok(())
}
```

**Step 4: Wire background tasks in main.rs**

```rust
// After building router, before serve:
let js = nats::setup_jetstream(&nats).await?;
tokio::spawn(dispatcher::run_dispatcher(state.clone(), js.clone()));
tokio::spawn(monitor::run_status_monitor(state.clone(), js.clone()));
```

**Step 5: Verify dispatcher compiles and publishes**

```bash
nix develop --command cargo build
```

**Step 6: Commit**

```bash
git commit -m "feat: NATS JetStream dispatcher and status monitor"
```

---

### Task 9: Agent run API + SSE proxy

**Files:**
- Create: `~/forge-api/src/handlers/runs.rs`

Endpoints:
```
GET /api/v1/tickets/:id/runs    → list all runs for ticket, ordered by queued_at desc
GET /api/v1/runs/:id            → single run
GET /api/v1/runs/:id/events     → SSE: proxy workstation-api GET /api/v1/workspaces/:ws_name/events
GET /api/v1/queue/status        → { queued: N, running: N, pool_capacity: N }
```

SSE proxy pattern (same as doable):

```rust
pub async fn run_events(
    State(state): State<Arc<AppState>>,
    Path(run_id): Path<Uuid>,
) -> Result<impl IntoResponse> {
    let run = /* fetch run */;
    let ws_name = run.workspace_name.ok_or_else(|| ApiError::BadRequest("run not started".into()))?;
    let url = format!("{}/api/v1/workspaces/{}/events", state.workstation_api_url, ws_name);
    // Stream the upstream SSE response directly as SSE
    let upstream = reqwest::get(&url).await
        .map_err(|e| ApiError::Upstream(e.to_string()))?;
    let stream = upstream.bytes_stream();
    Ok(axum::response::Response::builder()
        .header("content-type", "text/event-stream")
        .header("cache-control", "no-cache")
        .body(axum::body::Body::from_stream(stream))
        .unwrap())
}
```

**Step N: Commit**
```bash
git commit -m "feat: agent run API and SSE proxy"
```

---

## Phase 4: forge-api Docker + Deploy

### Task 10: Dockerfile and K8s manifests

**Files:**
- Create: `~/forge-api/Dockerfile`
- Create: `~/homelab-gitops/apps/forge/kustomization.yaml`
- Create: `~/homelab-gitops/apps/forge/namespace.yaml`
- Create: `~/homelab-gitops/apps/forge/postgres.yaml`
- Create: `~/homelab-gitops/apps/forge/nats.yaml`
- Create: `~/homelab-gitops/apps/forge/forge-api.yaml`

**Step 1: Write multi-stage Dockerfile**

```dockerfile
FROM rust:1.82-slim AS builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main(){}" > src/main.rs && cargo build --release && rm src/main.rs
COPY src ./src
COPY migrations ./migrations
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/forge-api /usr/local/bin/forge-api
COPY --from=builder /app/migrations /migrations
EXPOSE 8080
CMD ["forge-api"]
```

**Step 2: Build and push image**

```bash
cd ~/forge-api
buildah build --isolation=chroot -t registry.sammasak.dev/lab/forge-api:latest .
buildah push --authfile ~/.config/containers/auth.json registry.sammasak.dev/lab/forge-api:latest
```

**Step 3: Write K8s manifests**

`namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: forge
```

`postgres.yaml` — single-pod Postgres with PVC:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: forge
spec:
  replicas: 1
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        env:
        - name: POSTGRES_DB
          value: forge
        - name: POSTGRES_HOST_AUTH_METHOD
          value: trust
        - name: POSTGRES_USER
          value: forge
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: forge
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: forge
spec:
  selector: { app: postgres }
  ports:
  - port: 5432
```

`nats.yaml` — NATS with JetStream:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nats
  namespace: forge
spec:
  replicas: 1
  selector:
    matchLabels: { app: nats }
  template:
    metadata:
      labels: { app: nats }
    spec:
      containers:
      - name: nats
        image: nats:2.10-alpine
        args: ["-js", "-sd", "/data"]
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: nats-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nats-data
  namespace: forge
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
---
apiVersion: v1
kind: Service
metadata:
  name: nats
  namespace: forge
spec:
  selector: { app: nats }
  ports:
  - name: client
    port: 4222
  - name: monitor
    port: 8222
```

`forge-api.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forge-api
  namespace: forge
spec:
  replicas: 1
  selector:
    matchLabels: { app: forge-api }
  template:
    metadata:
      labels: { app: forge-api }
    spec:
      containers:
      - name: forge-api
        image: registry.sammasak.dev/lab/forge-api:latest
        env:
        - name: DATABASE_URL
          value: postgresql://forge@postgres.forge.svc.cluster.local/forge
        - name: NATS_URL
          value: nats://nats.forge.svc.cluster.local:4222
        - name: WORKSTATION_API_URL
          value: http://workstation-api.workstations.svc.cluster.local:8080
        - name: BIND_ADDR
          value: "0.0.0.0:8080"
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet: { path: /healthz, port: 8080 }
---
apiVersion: v1
kind: Service
metadata:
  name: forge-api
  namespace: forge
spec:
  selector: { app: forge-api }
  ports:
  - port: 8080
```

`kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
- postgres.yaml
- nats.yaml
- forge-api.yaml
```

**Step 4: Apply to cluster**

```bash
kubectl apply -k ~/homelab-gitops/apps/forge/
kubectl rollout status deployment/forge-api -n forge
```

**Step 5: Smoke test**

```bash
kubectl exec -n forge deployment/forge-api -- curl -s localhost:8080/healthz
```
Expected: `ok`

**Step 6: Commit GitOps manifests**

```bash
cd ~/homelab-gitops
git add apps/forge/
git commit -m "feat: forge namespace — postgres, nats, forge-api"
git push
```

---

## Phase 5: forge-ui

### Task 11: SvelteKit project scaffold

**Files:**
- Create: `~/forge-ui/` (SvelteKit project)

**Step 1: Create project**

```bash
cd ~ && npm create svelte@latest forge-ui
# choices: Skeleton project, TypeScript, ESLint+Prettier
cd forge-ui && npm install
npm install svelte-dnd-action
```

**Step 2: Configure adapter-node**

```bash
npm install -D @sveltejs/adapter-node
```

`svelte.config.js`:
```js
import adapter from '@sveltejs/adapter-node';
export default {
  kit: {
    adapter: adapter(),
    alias: { $api: 'src/lib/api' }
  }
};
```

**Step 3: Write API client** (`src/lib/api/forge.ts`)

```typescript
const BASE = '/api';

export interface Company {
  id: string;
  slug: string;
  name: string;
  githubRepoUrl?: string;
}

export interface Project {
  id: string;
  slug: string;
  name: string;
  companyId: string;
  columns: Column[];
}

export interface Column {
  id: string;
  name: string;
  position: number;
  agentConfig?: AgentConfig;
  tickets: Ticket[];
}

export interface AgentConfig {
  goalTemplate: string;
  instancetypeName?: string;
}

export interface Ticket {
  id: string;
  title: string;
  position: number;
  workspaceName?: string;
  latestRunStatus?: 'queued' | 'running' | 'done' | 'failed';
}

export interface AgentRun {
  id: string;
  ticketId: string;
  columnId: string;
  workspaceName?: string;
  status: 'queued' | 'running' | 'done' | 'failed';
  goal: string;
  queuedAt: string;
  startedAt?: string;
  endedAt?: string;
}

export const api = {
  companies: {
    list: () => fetch(`${BASE}/v1/companies`).then(r => r.json()) as Promise<Company[]>,
    create: (data: { slug: string; name: string; githubRepoUrl?: string }) =>
      fetch(`${BASE}/v1/companies`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json()),
    get: (slug: string) => fetch(`${BASE}/v1/companies/${slug}`).then(r => r.json()) as Promise<Company>,
  },
  projects: {
    get: (companySlug: string, projectSlug: string) =>
      fetch(`${BASE}/v1/companies/${companySlug}/projects/${projectSlug}`).then(r => r.json()) as Promise<Project>,
  },
  tickets: {
    move: (ticketId: string, columnId: string, position: number) =>
      fetch(`${BASE}/v1/tickets/${ticketId}/move`, {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ columnId, position }),
      }).then(r => r.json()),
    patch: (ticketId: string, data: { title?: string; description?: string }) =>
      fetch(`${BASE}/v1/tickets/${ticketId}`, {
        method: 'PATCH',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(data),
      }).then(r => r.json()),
  },
  runs: {
    list: (ticketId: string) =>
      fetch(`${BASE}/v1/tickets/${ticketId}/runs`).then(r => r.json()) as Promise<AgentRun[]>,
  },
};
```

**Step 4: Proxy API routes in SvelteKit** (`src/routes/api/[...path]/+server.ts`)

```typescript
import type { RequestHandler } from '@sveltejs/kit';

const FORGE_API = process.env.FORGE_API_URL ?? 'http://forge-api.forge.svc.cluster.local:8080';

export const GET: RequestHandler = async ({ params, request }) => {
  const url = `${FORGE_API}/api/${params.path}${new URL(request.url).search}`;
  return fetch(url, { headers: request.headers });
};
export const POST: RequestHandler = async ({ params, request }) => {
  const url = `${FORGE_API}/api/${params.path}`;
  return fetch(url, { method: 'POST', headers: request.headers, body: request.body, duplex: 'half' } as RequestInit);
};
export const PUT: RequestHandler = async ({ params, request }) => {
  const url = `${FORGE_API}/api/${params.path}`;
  return fetch(url, { method: 'PUT', headers: request.headers, body: request.body, duplex: 'half' } as RequestInit);
};
export const PATCH: RequestHandler = async ({ params, request }) => {
  const url = `${FORGE_API}/api/${params.path}`;
  return fetch(url, { method: 'PATCH', headers: request.headers, body: request.body, duplex: 'half' } as RequestInit);
};
export const DELETE: RequestHandler = async ({ params, request }) => {
  const url = `${FORGE_API}/api/${params.path}`;
  return fetch(url, { method: 'DELETE', headers: request.headers });
};
```

**Step 5: Commit**
```bash
git add . && git commit -m "chore: scaffold forge-ui with SvelteKit + API client"
```

---

### Task 12: Landing page and company home

**Files:**
- Create: `~/forge-ui/src/routes/+page.svelte` — list companies, create button
- Create: `~/forge-ui/src/routes/[company]/+page.svelte` — project list
- Create: `~/forge-ui/src/routes/[company]/+page.ts` — load company + projects
- Create: `~/forge-ui/src/routes/+page.ts` — load companies

Landing page design:
- Clean header: "Forge" + "New Company" button
- Grid of company cards: name, project count, github link
- Create company modal: name + slug (auto-generated from name) + optional github repo URL

**Step N: Commit**
```bash
git commit -m "feat: landing page and company home"
```

---

### Task 13: Kanban board

**Files:**
- Create: `~/forge-ui/src/routes/[company]/[project]/+page.svelte`
- Create: `~/forge-ui/src/routes/[company]/[project]/+page.ts`
- Create: `~/forge-ui/src/lib/components/KanbanColumn.svelte`
- Create: `~/forge-ui/src/lib/components/TicketCard.svelte`
- Create: `~/forge-ui/src/lib/components/AgentConfirmModal.svelte`

**Key implementation notes:**

Use `svelte-dnd-action` for drag-and-drop:

```svelte
<script>
  import { dndzone } from 'svelte-dnd-action';

  // columns is the ProjectBoardResponse.columns array
  // Each column.tickets is the items array for its dndzone

  function handleTicketDrop(columnId: string, e: CustomEvent) {
    const { items } = e.detail;
    const movedTicket = items.find(t => /* detect which ticket moved */);
    // compute new position using fractional indexing
    // if destination column has agentConfig → show confirmation modal
    // on confirm → api.tickets.move(...)
  }
</script>

{#each columns as column}
  <div class="column">
    <h3>{column.name} {#if column.agentConfig}🤖{/if}</h3>
    <div use:dndzone={{ items: column.tickets, flipDurationMs: 150 }}
         on:finalize={e => handleDrop(column.id, e)}>
      {#each column.tickets as ticket (ticket.id)}
        <TicketCard {ticket} />
      {/each}
    </div>
  </div>
{/each}
```

**Fractional indexing for position:**
```typescript
function positionBetween(before: number | null, after: number | null): number {
  if (before === null && after === null) return 0.5;
  if (before === null) return after! / 2;
  if (after === null) return before + 1;
  return (before + after) / 2;
}
```

**Agent confirmation modal** — shown when dropping to an agent-enabled column:
```
"Start [Ideation] agent on 'Fix login bug'?"
[Cancel]  [Start Agent]
```

Ticket card shows status badge:
- `queued` → gray "Queued"
- `running` → blue pulsing "Building"
- `done` → green "Done"
- `failed` → red "Failed"
- no run → nothing

**SSE for live ticket status updates** — subscribe to `forge.events.{ticket_id}` via a server-sent event endpoint. Update the ticket's `latestRunStatus` in the board state when a message arrives.

**Step N: Commit**
```bash
git commit -m "feat: kanban board with drag-and-drop and agent dispatch"
```

---

### Task 14: Ticket detail page

**Files:**
- Create: `~/forge-ui/src/routes/[company]/[project]/tickets/[id]/+page.svelte`
- Create: `~/forge-ui/src/routes/[company]/[project]/tickets/[id]/+page.ts`

Features:
- Editable title (click to edit, blur to save)
- Markdown editor for description (textarea, saves on blur)
- Agent run history: timeline with column name, status badge, timestamp, collapsible goal preview
- Active run: live log via SSE from `/api/v1/runs/:id/events`
- Link to VM preview URL if `workspaceName` is set

**Step N: Commit**
```bash
git commit -m "feat: ticket detail with agent run history and live log"
```

---

### Task 15: Project settings page

**Files:**
- Create: `~/forge-ui/src/routes/[company]/[project]/settings/+page.svelte`

Features:
- Column manager: drag to reorder, click to rename, delete button (disabled if has tickets)
- Add column button → inline name input
- Per-column agent config:
  - Toggle "Enable agent on ticket arrival"
  - Textarea for goal template with `{{placeholder}}` hints shown below
  - Instancetype dropdown: workstation-standard
  - "Preview rendered goal" button — shows sample render with dummy ticket

**Step N: Commit**
```bash
git commit -m "feat: project settings with column and agent config editor"
```

---

## Phase 6: forge-ui Docker + Deploy

### Task 16: Build, push, deploy forge-ui

**Files:**
- Create: `~/forge-ui/Dockerfile`
- Create: `~/homelab-gitops/apps/forge/forge-ui.yaml`
- Modify: `~/homelab-gitops/apps/forge/kustomization.yaml`

**Step 1: Dockerfile**

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json .
ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000
CMD ["node", "build"]
```

**Step 2: Build and push**

```bash
cd ~/forge-ui
npm run build
buildah build --isolation=chroot -t registry.sammasak.dev/lab/forge-ui:latest .
buildah push --authfile ~/.config/containers/auth.json registry.sammasak.dev/lab/forge-ui:latest
```

**Step 3: K8s forge-ui.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forge-ui
  namespace: forge
spec:
  replicas: 1
  selector:
    matchLabels: { app: forge-ui }
  template:
    metadata:
      labels: { app: forge-ui }
    spec:
      containers:
      - name: forge-ui
        image: registry.sammasak.dev/lab/forge-ui:latest
        env:
        - name: FORGE_API_URL
          value: http://forge-api.forge.svc.cluster.local:8080
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet: { path: /, port: 3000 }
---
apiVersion: v1
kind: Service
metadata:
  name: forge-ui
  namespace: forge
spec:
  selector: { app: forge-ui }
  ports:
  - port: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: forge
  namespace: forge
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  rules:
  - host: forge.sammasak.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: forge-ui
            port:
              number: 3000
```

**Step 4: Apply and verify**

```bash
kubectl apply -k ~/homelab-gitops/apps/forge/
kubectl rollout status deployment/forge-ui -n forge
curl -s https://forge.sammasak.dev | grep -i forge
```

**Step 5: Commit and push GitOps**

```bash
cd ~/homelab-gitops
git add apps/forge/
git commit -m "feat: add forge-ui deployment and ingress"
git push
```

---

## Phase 7: GitHub repos + final wiring

### Task 17: Push both repos to GitHub

```bash
# forge-api
cd ~/forge-api
gh repo create sammasak/forge-api --private --source=. --push

# forge-ui
cd ~/forge-ui
gh repo create sammasak/forge-ui --private --source=. --push
```

### Task 18: Smoke test end-to-end

```bash
# Create a company
curl -X POST https://forge.sammasak.dev/api/v1/companies \
  -H 'content-type: application/json' \
  -d '{"slug":"acme","name":"Acme Corp","githubRepoUrl":"https://github.com/sammasak/workspace"}'

# Create a project
curl -X POST https://forge.sammasak.dev/api/v1/companies/acme/projects \
  -H 'content-type: application/json' \
  -d '{"slug":"platform","name":"Platform"}'

# Verify default columns created
curl https://forge.sammasak.dev/api/v1/companies/acme/projects/platform | jq '.columns[].name'
# Expected: "Backlog", "Ideation", "In Progress", "Review", "Done"

# Create a ticket
curl -X POST https://forge.sammasak.dev/api/v1/columns/<backlog-column-id>/tickets \
  -H 'content-type: application/json' \
  -d '{"title":"Build auth system","description":"Add JWT-based authentication"}'

# Open browser: https://forge.sammasak.dev
```

---

## Key Things to Know

**Slug rules:** lowercase, alphanumeric + hyphens, 1-63 chars. Same as k8s DNS labels.

**Fractional indexing:** Ticket `position` is a float. Moving to front: `position = first_position / 2`. Moving between: `position = (before + after) / 2`. No bulk updates.

**NATS subject format:** `forge.dispatch.{agent_run_id}` — the UUID is the subject suffix, allowing consumer to fetch the specific run from DB.

**workstation-api pool claiming:** forge-api passes `bootstrapSecretName` and `containerDiskImage` from env. These match what workstation-api already uses for pool VMs (`claude-worker-bootstrap`, `registry.sammasak.dev/agents/claude-worker:latest`).

**ICM clone preamble:** If company has `githubRepoUrl`, forge-api prepends `git clone <url> .company-context 2>/dev/null && cat .company-context/CLAUDE.md || echo "no context"` to the rendered goal. Agent reads company context before working.

**sqlx compile-time checks:** Use `sqlx::query_as!` macros. Run `cargo sqlx prepare` after any schema change to update `.sqlx/` offline cache (committed to git for CI).

**Pre-commit hooks:** Run `nix develop --command git commit` to get cargo in scope for fmt + clippy hooks (same pattern as workstation-api).
