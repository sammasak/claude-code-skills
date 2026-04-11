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
| **SvelteKit 2 dev server** | Port 8080, Vite HMR active |
| **PostgreSQL 16** | `localhost:5432`, db `claude`, user `claude`, no password |
| **Node.js + node_modules** | Pre-installed in `/var/lib/claude-worker/workspace/` |

**Do NOT:**
- Run `npm install` — node_modules are present.
- Start `vite`, `npm run dev` — already running.
- Build a container for preview — Vite HMR pushes changes live.

**Connection string:** `postgresql://claude@localhost/claude`
**Workspace root:** `/var/lib/claude-worker/workspace/`

## 2. Project Structure

```
workspace/
├── src/
│   ├── routes/
│   │   ├── +page.svelte             # Start here — replace placeholder
│   │   ├── +layout.svelte           # Global layout
│   │   └── api/health/+server.ts    # Health check — do NOT overwrite
│   ├── lib/components/              # Shared Svelte components
│   ├── app.css                      # Global styles + Tailwind v4
│   └── app.html                     # HTML shell
├── schema.sql                       # Create it if you need a DB
├── vite.config.ts                   # Do NOT modify port/host
└── package.json
```

## 3. Reference Documentation

Read `docs/template-stack-reference.md` for:
- Svelte 5 Runes API (`$state`, `$derived`, `$props`, `$effect`)
- Tailwind CSS v4 usage and `@import`
- SvelteKit server routes (+server.ts) and PostgreSQL pool
- Adding a Rust backend proxy via Vite
- Production deployment commands (buildah, container registry)
- Repo mode (setting up clones from GitHub)

Use this skill at the **start of every new project** to orient yourself. Do not set up your own dev server, install Node.js, or initialize PostgreSQL. The environment is ready — start building.
