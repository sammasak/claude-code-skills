---
name: template-stack
description: "Use at the START of every new project inside a claude-worker VM. Describes the pre-baked SvelteKit 2 + PostgreSQL 16 environment that is already running — do not re-install Node, start a dev server, or set up a database."
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
injectable: true
---

# Template Stack

The claude-worker VM ships with a complete SvelteKit 2 (Svelte 5) + PostgreSQL 16 environment pre-configured and already running. Read this before writing a single line of code.

## 1. Environment — What Is Already Running

| Service | Details |
|---|---|
| **SvelteKit 2 dev server** | Running on port 8080, Vite HMR active |
| **PostgreSQL 16** | `localhost:5432`, database `claude`, user `claude`, no password (trust auth) |
| **Node.js + node_modules** | Pre-installed in `/var/lib/claude-worker/workspace/` |

**Do NOT:**
- Run `npm install` — node_modules are already present
- Start `vite`, `npm run dev`, or any other dev server — it is already running
- Build a container for preview — Vite HMR pushes changes live within 1-2 seconds
- Install PostgreSQL or initialize a database — it is already running

**Connection string:** `postgresql://claude@localhost/claude`

**Workspace root:** `/var/lib/claude-worker/workspace/`

## 2. Project Structure

```
workspace/
├── src/
│   ├── routes/
│   │   ├── +page.svelte             # Start here — replace placeholder with real UI
│   │   ├── +layout.svelte           # Global layout (fonts, global styles)
│   │   └── api/
│   │       └── health/
│   │           └── +server.ts       # Health check endpoint — do NOT overwrite
│   ├── lib/
│   │   └── components/              # Shared Svelte components
│   ├── app.css                      # Global styles + Tailwind import — add global CSS here
│   └── app.html                     # HTML shell — add <link> tags for fonts here
├── schema.sql                       # Does NOT exist by default — create it if you need a DB
├── vite.config.ts                   # Do NOT modify port/host settings
└── package.json
```

## 3. Svelte 5 Runes

The runtime is **Svelte 5** — use the runes API exclusively. Do NOT use Svelte 4 reactive syntax.

| Svelte 4 (wrong) | Svelte 5 runes (correct) |
|---|---|
| `export let count = 0;` | `let count = $state(0);` |
| `export let name;` (prop) | `let { name } = $props();` |
| `$: doubled = count * 2` | `let doubled = $derived(count * 2)` |
| `$: { ... }` side-effect | `$effect(() => { ... })` |
| `<slot />` | `{@render children()}` |

Always use `$state()`, `$derived()`, `$props()`, and `$effect()` — never `$:` labels or `export let` for props.

## 4. Modifying the UI

- Edit `src/routes/+page.svelte` to replace the placeholder loader with the actual app UI
- Add new pages as `src/routes/[page-name]/+page.svelte`
- Add reusable Svelte components to `src/lib/components/`
- Changes hot-reload within 1-2 seconds — no restart or rebuild needed

## 5. Tailwind CSS v4

Tailwind v4 is fully wired — just use utility classes in `.svelte` files.

- The `@tailwindcss/vite` plugin is already configured in `vite.config.ts`
- `src/app.css` already contains `@import 'tailwindcss'` — do not remove it
- Add global CSS and Tailwind plugin directives to `src/app.css`, for example:
  ```css
  @import 'tailwindcss';
  @plugin "@tailwindcss/forms";
  ```
- Do not modify `tailwind.config.ts` — it is a Tailwind v3 artifact that has no effect under v4

No configuration changes needed. Use utility classes directly in `.svelte` files.

## 6. Adding API Endpoints (SvelteKit Server Routes)

SvelteKit server routes (`+server.ts`) run on the Node.js server and have direct database access:

```typescript
// src/routes/api/items/+server.ts
import { json } from '@sveltejs/kit';
import pg from 'pg';

const pool = new pg.Pool({ connectionString: 'postgresql://claude@localhost/claude' });

export async function GET() {
  const { rows } = await pool.query('SELECT * FROM items ORDER BY created_at DESC');
  return json(rows);
}

export async function POST({ request }) {
  const body = await request.json();
  const { rows } = await pool.query(
    'INSERT INTO items (name) VALUES ($1) RETURNING *',
    [body.name]
  );
  return json(rows[0], { status: 201 });
}
```

Call these from the frontend with `fetch('/api/items')`.

## 7. Adding Database Tables

`schema.sql` does **not** exist in the template — create it at the workspace root if your app needs a database. The systemd service applies it automatically on startup if it exists. You can also apply it manually:

```bash
psql postgresql://claude@localhost/claude < /var/lib/claude-worker/workspace/schema.sql
```

**Keep schemas idempotent** — always use `CREATE TABLE IF NOT EXISTS` so re-running `schema.sql` is safe:

```sql
CREATE TABLE IF NOT EXISTS items (
  id         SERIAL PRIMARY KEY,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

No migrations framework. Direct SQL only.

## 8. Optional Rust Backend

Only reach for Rust when SvelteKit server routes are genuinely insufficient — high-throughput computation, WebSockets, or long-running background jobs:

```bash
mkdir -p /var/lib/claude-worker/workspace/backend
cd /var/lib/claude-worker/workspace/backend
cargo init
# Add axum, tokio, sqlx to Cargo.toml
# Run on port 3001
cargo watch -x run   # auto-rebuilds on file change
```

Proxy Rust API calls through Vite by editing the `server` block in `vite.config.ts`. The block already has port/host settings — merge `proxy` into it, do not replace the block:

```typescript
server: {
  port: 8080,
  host: '0.0.0.0',
  strictPort: true,
  proxy: {
    '/rust-api': 'http://localhost:3001'
  }
}
```

Frontend then calls `/rust-api/...` — no CORS configuration needed.

## 9. Production Deployment

Run this when the app is functionally complete and the user has approved it:

```bash
cd /var/lib/claude-worker/workspace

# 1. Build the SvelteKit production bundle
npm run build

# 2. Create a Containerfile (replace PLACEHOLDER with the actual subdomain)
cat > Containerfile << 'EOF'
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY build ./build
ENV NODE_ENV=production
ENV PORT=3000
ENV ORIGIN=https://PLACEHOLDER.sammasak.dev
EXPOSE 3000
CMD ["node", "build/index.js"]
EOF

# 3. Build the container image
buildah build --isolation=chroot \
  -t registry.sammasak.dev/apps/[project-name]:latest .

# 4. Push the image
buildah push \
  --authfile /var/lib/claude-worker/.config/containers/auth.json \
  registry.sammasak.dev/apps/[project-name]:latest

# 5. Apply Kubernetes manifests (see CLAUDE.md deployment section)
```

Replace `[project-name]` with a short kebab-case name for the app (e.g. `expense-tracker`, `notes-app`), and replace `PLACEHOLDER` in the `Containerfile` with the actual subdomain.

## 10. Repo Mode (When Workspace Was Cloned from GitHub)

If your goal starts with "Before starting, set up the workspace:", you are in **repo mode**. The workspace contains a cloned GitHub repo, not the default SvelteKit template.

**First actions (always do these before anything else):**

```bash
# 1. Understand the repo
git log --oneline -5
ls -la ~/workspace/

# 2. Detect the stack
cat ~/workspace/package.json 2>/dev/null | head -20   # JS/TS
cat ~/workspace/Cargo.toml 2>/dev/null | head -10     # Rust
cat ~/workspace/pyproject.toml 2>/dev/null | head -10 # Python
cat ~/workspace/go.mod 2>/dev/null | head -5          # Go

# 3. Check for flake.nix
ls ~/workspace/flake.nix 2>/dev/null || echo "No flake.nix — create one"
```

**If no `flake.nix` exists, create one for the detected stack.** Examples:

*Node.js/SvelteKit:*
```nix
{
  inputs.nixpkgs.url = "nixpkgs";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_22 pkgs.postgresql_16 ];
      };
    };
}
```

*Python:*
```nix
{
  inputs.nixpkgs.url = "nixpkgs";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python312 pkgs.uv ];
      };
    };
}
```

**Start the dev server on `:8080` in the background:**

```bash
# SvelteKit — template-dev handles this automatically if "vite" key is in package.json
# If it's NOT running (check: curl -sf localhost:8080), start manually:
nix develop --command npm run dev -- --port 8080 --host 0.0.0.0 &

# Python (FastAPI / uvicorn):
nix develop --command uvicorn main:app --host 0.0.0.0 --port 8080 --reload &

# Go:
nix develop --command go run . &   # ensure your server listens on :8080

# Rust (axum/actix):
nix develop --command cargo watch -x run &   # ensure your server listens on :8080
```

Then work on the user's goal. Everything else in this skill still applies: deploy via buildah, use port :8080 for live preview, Kubernetes manifests go to the homelab-gitops repo.

## 11. When to Use This Skill

Use this skill at the **start of every new project** to orient yourself before touching any files. It answers:

- What is already running and what you must not restart
- Where to put UI code, API routes, and database schema
- How changes reach the browser (HMR — no manual refresh or rebuild)
- How to write Svelte 5 components with runes
- How to use Tailwind CSS v4
- When and how to add a Rust backend
- How to produce the final deployable container

Do not set up your own dev server, install Node.js, initialize PostgreSQL, or run `npm install`. The environment is ready — start building.
