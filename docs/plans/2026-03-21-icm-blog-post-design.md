# ICM Blog Post — Design Document

**Date:** 2026-03-21
**URL:** icm.sammasak.dev
**Audience:** Yourself + technical builders who want to adopt ICM for their own Claude Code workflows

---

## Goal

A scrollable, animated blog post that:
1. Explains Jake Van Clief's ICM (Interpreted Context Methodology)
2. Shows our concrete implementation in `~/workspace`
3. Gives readers enough to copy the pattern for their own setup

---

## Architecture

**Deployment:**
- Single `index.html` (~700–1000 lines) — all CSS and JS inline, zero external deps
- Served by `nginx:alpine` in Kubernetes
- HTML content mounted via Kubernetes `ConfigMap`
- Ingress at `icm.sammasak.dev` using existing `wildcard-sammasak-dev-tls` secret
- Registered in `~/homelab-gitops/apps/kustomization.yaml`
- Flux reconciles on git push — no build step required

**Files to create:**
- `~/homelab-gitops/apps/icm/namespace.yaml`
- `~/homelab-gitops/apps/icm/configmap.yaml` (contains index.html)
- `~/homelab-gitops/apps/icm/deployment.yaml`
- `~/homelab-gitops/apps/icm/service.yaml`
- `~/homelab-gitops/apps/icm/ingress.yaml`
- `~/homelab-gitops/apps/icm/kustomization.yaml`
- Update `~/homelab-gitops/apps/kustomization.yaml` to add `- icm/`

---

## Visual Language

| Property | Value |
|----------|-------|
| Background | `#080808` (near black) |
| Primary text | `#e8e8e8` |
| Accent | `#6366f1` (indigo — Claude's palette) |
| Secondary accent | `#a78bfa` (lighter purple) |
| Code bg | `#0f0f1a` |
| Borders | `#1e1e30` |
| Success green | `#34d399` |
| Headlines | `system-ui, -apple-system, sans-serif`, heavy weight |
| Code | `'JetBrains Mono', 'Fira Code', monospace` |

**Animation technique:** CSS `@keyframes` + `Intersection Observer` for scroll-triggered entry. SVG line drawings via `stroke-dashoffset`. Token counter via `requestAnimationFrame`. No external libraries.

---

## Page Sections

### 1. Hero
- Full viewport height
- Title: **"Interpreted Context Methodology"** — letters fade up staggered
- Subtitle: "How a folder structure replaced agent frameworks"
- Three concentric glowing rings (SVG) representing the 3 layers, slowly rotating
- Author chip + date + "↓ scroll" pulse arrow

### 2. The Problem — Token Bloat
- Section header: "The problem with loading everything"
- Animated progress bar filling up: `0 → 50,000 tokens` (ticking counter)
- Bar turns red at ~30k, label appears: "Model quality degrades here"
- Two columns: "What you load" (big list fades in) vs "What Claude needs" (3 lines)
- Payoff line: *"The gap between what you load and what you need is where quality dies."*

### 3. The Three-Layer System
- Section header: "Jake Van Clief's solution"
- Three horizontal layers animate in from left on scroll:
  - **Layer 1** — `CLAUDE.md` — "Always loaded. ~800 tokens. The map."
  - **Layer 2** — `CONTEXT.md rooms` — "Loaded on demand. The rooms."
  - **Layer 3** — `Skills / tools` — "Injected selectively. The knowledge."
- Connecting SVG lines draw between layers as each appears
- Token budget indicator per layer (tiny chip on right)

### 4. Routing — How It Works
- Section header: "Deterministic routing — no guessing"
- The actual routing table from `CLAUDE.md` renders row by row
- On hover/scroll-in: a task row highlights → an animated arrow flows right → the matched room CONTEXT.md appears → skills that load appear as floating chips
- Three example flows animate automatically: homelab task → dev task → workflow task
- Contrast label: *"Skills: description matching (implicit). ICM: routing table (deterministic)."*

### 5. The Workspace Tree
- Section header: "Our implementation"
- Animated directory tree that expands node by node on scroll:
  ```
  ~/workspace/
  ├── CLAUDE.md          ← always loaded
  ├── homelab/CONTEXT.md ← loaded for k8s/nixos tasks
  ├── dev/CONTEXT.md     ← loaded for code tasks
  ├── local/CONTEXT.md   ← loaded for local scripts
  └── workflows/
      ├── CONTEXT.md     ← workflow gateway
      ├── deploy-service/CONTEXT.md
      ├── provision-vm/CONTEXT.md
      └── release-nixos/CONTEXT.md
  ```
- Each node has a hover tooltip: what it's for, when it loads
- Token cost chip on each file (e.g. `CLAUDE.md → ~800 tok`)

### 6. A Workflow in Action
- Section header: "Tracing a task end-to-end"
- Input prompt appears letter by letter: `"Deploy the doable UI service"`
- Step-by-step animated trace:
  1. CLAUDE.md scanned → routing table row lights up
  2. Arrow flows to `workflows/CONTEXT.md`
  3. Arrow flows to `deploy-service/CONTEXT.md`
  4. Stage 1 → 2 → 3 → 4 blocks appear in sequence with exact commands
- Each step has a token count update (shows cumulative tokens loaded, far less than "load everything")

### 7. How to Adapt It
- Section header: "Build your own"
- Three numbered steps with expandable code blocks:
  1. **Create your CLAUDE.md** — template with routing table (copy button)
  2. **Create your rooms** — CONTEXT.md template for one domain (copy button)
  3. **Create your workflows** — stage contract template (copy button)
- Minimal commentary, code does the talking

### 8. What It Replaces
- Section header: "Before and after"
- Split panel (left vs right):
  - Left: "Skills only" — list of skills, description matching, implicit routing
  - Right: "ICM + Skills" — CLAUDE.md table, deterministic, skills still run alongside
- Animated "tokens saved" counter (difference between monolithic and selective)
- Closing line: *"The filesystem is the orchestration layer."*

### Footer
- Attribution: "Based on Jake Van Clief's ICM — @lostandlucky"
- Link to the workspace repo (github.com/sammasak/workspace)
- "Built with Claude Code"

---

## Animation Choreography

| Section | Trigger | Animation |
|---------|---------|-----------|
| Hero title | page load | staggered letter fade-up, 50ms delay per letter |
| Hero rings | page load | slow rotation (60s), pulse glow |
| Token counter | enters viewport | rAF counter 0→50000 over 3s |
| Layer cards | enters viewport | slide-in-left, 200ms stagger |
| SVG connectors | after layers render | stroke-dashoffset 0→length, 600ms |
| Routing table rows | enters viewport | fade-up, 80ms stagger per row |
| Routing hover flow | hover | CSS transition + animated dashed line |
| Directory tree nodes | scroll position | sequential reveal, 100ms per node |
| Workflow trace steps | enters viewport | typewriter for commands, 200ms stagger |
| Code blocks | enters viewport | fade-in, syntax highlighting via CSS |
| Split panel | enters viewport | slide-in from sides simultaneously |

---

## Kubernetes Manifests (summary)

**Namespace:** `icm`, PSS label `baseline`
**Deployment:** 1 replica, `nginx:alpine`, mounts ConfigMap at `/usr/share/nginx/html/`
**Service:** ClusterIP port 80
**Ingress:** `ingressClassName: nginx`, host `icm.sammasak.dev`, TLS from `wildcard-sammasak-dev-tls`
**Security context:** `runAsNonRoot: true`, `runAsUser: 101` (nginx user), `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: false` (nginx needs /var/cache/nginx)

---

## Success Criteria

- Loads in < 2s (single file, no external deps)
- Works without JavaScript (animations are progressive enhancement)
- Passes the "does this make ICM click?" test on first read
- Code blocks are accurate (match actual workspace files)
- All 8 sections render correctly on 1920×1080 and 1440×900
