# ICM Workspace Repo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `sammasak/workspace` — a private GitHub repo at `~/workspace` that implements Jake Van Clief's ICM folder architecture as a local-first AI workspace running in parallel with claude-code-skills.

**Architecture:** Three-layer ICM — `CLAUDE.md` at root (always-loaded map + routing table), per-workspace `CONTEXT.md` files (Layer 2), and `workflows/` with named multi-step pipeline CONTEXT.md files. No `references/` folder yet — add when duplication becomes a real problem. Skills still inject via the existing description-matching system; this workspace provides navigation and sequencing on top.

**Tech Stack:** Markdown, Git, GitHub CLI (`gh`). No code, no frameworks.

---

### Task 1: Create the GitHub repo and local directory

**Files:**
- Create: `~/workspace/` (directory)

**Step 1: Create the private GitHub repo**

```bash
gh repo create sammasak/workspace --private --description "ICM workspace — Jake Van Clief pattern"
```

Expected: repo created at `github.com/sammasak/workspace`

**Step 2: Clone it locally**

```bash
git clone git@github.com:sammasak/workspace.git ~/workspace
cd ~/workspace
```

Expected: empty repo at `~/workspace`

**Step 3: Create the directory structure**

```bash
mkdir -p ~/workspace/homelab
mkdir -p ~/workspace/dev
mkdir -p ~/workspace/local
mkdir -p ~/workspace/content
mkdir -p ~/workspace/workflows/deploy-service
mkdir -p ~/workspace/workflows/provision-vm
mkdir -p ~/workspace/workflows/release-nixos
```

**Step 4: Verify structure**

```bash
find ~/workspace -type d | sort
```

Expected:
```
/home/lukas/workspace
/home/lukas/workspace/content
/home/lukas/workspace/dev
/home/lukas/workspace/homelab
/home/lukas/workspace/local
/home/lukas/workspace/workflows
/home/lukas/workspace/workflows/deploy-service
/home/lukas/workspace/workflows/provision-vm
/home/lukas/workspace/workflows/release-nixos
```

---

### Task 2: Write CLAUDE.md (Layer 1 — always-loaded map)

**Files:**
- Create: `~/workspace/CLAUDE.md`

**Step 1: Write the file**

Target: ~800 tokens. This is the file Claude reads first on every session. It must answer: where am I, what rooms exist, what task goes where, which skills to load alongside.

```markdown
# Workspace

You are working in Lukas's personal ICM workspace. Read this file first on every task — it is the map.

## Rooms

| Room | What it's for |
|------|---------------|
| `homelab/` | Kubernetes cluster, NixOS hosts, Flux GitOps, SOPS secrets, VM management |
| `dev/` | Application development — doable (SvelteKit), workstation-api (Rust), feature work |
| `local/` | Personal scripts, tool configs, one-off local automation |
| `content/` | Research notes, writing, docs, learning content |
| `workflows/` | Named multi-step pipelines that span rooms |

## Routing Table

| Task | Go to | Also invoke skill |
|------|-------|-------------------|
| Deploy a service | `workflows/deploy-service/CONTEXT.md` | container-workflows, credentials, kubernetes-gitops, verify-service |
| Provision a claude-worker VM | `workflows/provision-vm/CONTEXT.md` | claude-ctl |
| Release NixOS config | `workflows/release-nixos/CONTEXT.md` | nix-flake-development |
| Kubernetes / Flux / Helm work | `homelab/CONTEXT.md` | kubernetes-gitops, secrets-management |
| NixOS / Home Manager work | `homelab/CONTEXT.md` | nix-flake-development, secrets-management |
| SOPS secrets | `homelab/CONTEXT.md` | secrets-management |
| doable UI work | `dev/CONTEXT.md` | template-stack, e2e-testing |
| workstation-api work | `dev/CONTEXT.md` | rust-engineering, observability-patterns |
| New service / greenfield | `dev/CONTEXT.md` | python-engineering or rust-engineering |
| Personal script / automation | `local/CONTEXT.md` | whichever language skill applies |
| Writing / research / notes | `content/CONTEXT.md` | — |

## Key Repos on Disk

| Repo | Path | Purpose |
|------|------|---------|
| homelab-gitops | `~/homelab-gitops` | Flux manifests, Kubernetes state |
| nixos-config | `~/nixos-config` | NixOS host configs |
| workstation-api | `~/workstation-api` | Rust Axum API |
| doable | `/tmp/doable` | SvelteKit frontend |
| claude-code-skills | `~/claude-code-skills` | Skills library (parallel system) |

## Rules

- Read the relevant room's CONTEXT.md before starting any task
- Invoke the listed skills alongside — they carry domain knowledge this workspace doesn't duplicate
- Do not load a room's CONTEXT.md unless the task belongs there
- When uncertain which room applies, ask
```

**Step 2: Count approximate tokens**

```bash
wc -w ~/workspace/CLAUDE.md
```

Expected: under 400 words (~530 tokens). Good — well within the 800-token budget.

**Step 3: Commit**

```bash
cd ~/workspace
git add CLAUDE.md
git commit -m "feat: add CLAUDE.md — Layer 1 workspace map and routing table"
```

---

### Task 3: Write homelab/CONTEXT.md

**Files:**
- Create: `~/workspace/homelab/CONTEXT.md`

**Step 1: Write the file**

```markdown
# Homelab

This room covers all infrastructure work: Kubernetes cluster management, NixOS host configuration, Flux GitOps reconciliation, SOPS secret management, and KubeVirt VM operations.

## What lives here

- **Cluster state** — Flux kustomizations, HelmReleases, namespace configs in `~/homelab-gitops`
- **Host configs** — NixOS modules, host-specific configs in `~/nixos-config`
- **Secrets** — SOPS-encrypted secrets (age keys), Kubernetes Secret manifests
- **VMs** — KubeVirt VMIs, claude-worker provisioning via claude-ctl

## Skills to invoke

Always invoke these alongside homelab work:
- `kubernetes-gitops` — Flux patterns, HelmRelease structure, reconciliation commands
- `nix-flake-development` — NixOS module patterns, rebuild workflow, flake.lock hygiene
- `secrets-management` — SOPS encrypt/decrypt, age keypairs, Flux SOPS integration

## Common tasks

**Deploying a manifest change:**
1. Edit file in `~/homelab-gitops`
2. `git push` → Flux picks up automatically (poll interval ~1min)
3. `flux get all -A` to watch reconciliation
4. If urgent: `flux reconcile kustomization <name> --with-source`

**Adding a secret:**
See secrets-management skill — canonical SOPS workflow lives there.

**Rebuilding a NixOS host:**
See nix-flake-development skill — rebuild workflow lives there.
For remote hosts: `just deploy <hostname>` from `~/nixos-config`

**Provisioning a claude-worker VM:**
Use `workflows/provision-vm/` — full pipeline with goal seeding.

## Key files

| File | Purpose |
|------|---------|
| `~/homelab-gitops/apps/workstations/kustomization.yaml` | Main workstations kustomization |
| `~/nixos-config/modules/homelab/workstation-image.nix` | Golden VM image packages |
| `~/nixos-config/modules/homelab/claude-worker.nix` | Claude worker NixOS module |
| `~/.config/claude-ctl/config.toml` | claude-ctl API config |

## Cluster info

- **Nodes:** acer-swift (primary), msi-ms7758 (worker — goes offline periodically)
- **Registry:** `registry.sammasak.dev` — Harbor instance
- **Secrets backend:** SOPS + age encryption
```

**Step 2: Commit**

```bash
cd ~/workspace
git add homelab/CONTEXT.md
git commit -m "feat: add homelab workspace CONTEXT.md"
```

---

### Task 4: Write dev/CONTEXT.md

**Files:**
- Create: `~/workspace/dev/CONTEXT.md`

**Step 1: Write the file**

```markdown
# Dev

This room covers application development work — building features, fixing bugs, and shipping changes to the services running in the homelab.

## Services

| Service | Stack | Path | Port |
|---------|-------|------|------|
| doable | SvelteKit 2, Svelte 5, Tailwind v4, PostgreSQL | `/tmp/doable` | 5173 (dev) |
| workstation-api | Rust, Axum, PostgreSQL | `~/workstation-api` | 8080 |

## Skills to invoke

- `template-stack` — when working on doable (SvelteKit patterns, Svelte 5 runes, Tailwind v4, PostgreSQL schema)
- `rust-engineering` — when working on workstation-api (Axum patterns, error handling, Cargo workspace)
- `e2e-testing` — when verifying UI flows (Playwright MCP)
- `observability-patterns` — when adding metrics/logging to any service
- `container-workflows` — when building/pushing images
- `credentials` — when pushing to registry or deploying

## Deploy flow for either service

Use `workflows/deploy-service/` — that pipeline covers build → push → apply → verify.

## doable specifics

- Dev server: `npm run dev` in `/tmp/doable` (runs on 5173)
- Build: `npm run build` then `buildah build --isolation=chroot`
- Push: `buildah push --creds "admin:Harbor12345" registry.sammasak.dev/lab/doable-ui:latest`
- Apply: `kubectl rollout restart deployment/doable -n doable`
- Svelte 5 syntax: use runes (`$state`, `$derived`, `$effect`) — not Svelte 4 stores

## workstation-api specifics

- Build: `just release` from `~/workstation-api`
- Deploy: `kubectl rollout restart deployment/workstation-api -n workstations`
- Key files: `src/crd.rs` (CRD types), `src/handlers.rs` (Axum routes)
```

**Step 2: Commit**

```bash
cd ~/workspace
git add dev/CONTEXT.md
git commit -m "feat: add dev workspace CONTEXT.md"
```

---

### Task 5: Write local/CONTEXT.md and content/CONTEXT.md

**Files:**
- Create: `~/workspace/local/CONTEXT.md`
- Create: `~/workspace/content/CONTEXT.md`

**Step 1: Write local/CONTEXT.md**

```markdown
# Local

This room is for personal scripts, tool configurations, one-off automation, and anything that runs on this machine rather than in the cluster.

## What belongs here

- Shell scripts and utilities
- Tool configuration files
- Local data processing / transformation
- Anything exploratory that doesn't fit another room

## Skills to invoke

Use whichever language skill matches the task:
- `python-engineering` — for Python scripts, data work
- `rust-engineering` — for compiled tools
- No skill needed for simple shell scripts

## Rules

- Scripts go in `local/scripts/` if you create them here
- Keep it simple — if it becomes a real service, move to `dev/`
```

**Step 2: Write content/CONTEXT.md**

```markdown
# Content

This room is for research, notes, writing, and learning content. No code, no deployments.

## What belongs here

- Research summaries (e.g. notes from reading a blog post or watching a video)
- Design thinking / planning docs before they become formal plans
- Writing drafts
- Notes from communities, courses, reading

## Rules

- Output goes in `content/notes/` or `content/drafts/` as markdown files
- Date-prefix filenames: `2026-03-18-icm-research.md`
- This is a low-stakes room — write freely, edit later
```

**Step 3: Commit**

```bash
cd ~/workspace
git add local/CONTEXT.md content/CONTEXT.md
git commit -m "feat: add local and content workspace CONTEXT.md files"
```

---

### Task 6: Write workflows/CONTEXT.md

**Files:**
- Create: `~/workspace/workflows/CONTEXT.md`

**Step 1: Write the file**

```markdown
# Workflows

A workflow is a named, multi-step pipeline. Each subfolder is one workflow with its own CONTEXT.md defining the stages, inputs, and outputs.

## Available workflows

| Workflow | What it does | When to use it |
|----------|-------------|----------------|
| `deploy-service/` | build → push → apply → verify | Shipping any service to the cluster |
| `provision-vm/` | provision → seed goal → watch | Spinning up a claude-worker VM |
| `release-nixos/` | build → switch → push | Releasing a NixOS config change |

## How to run a workflow

1. Read CLAUDE.md to confirm this is the right workflow
2. Read the workflow's CONTEXT.md — it defines what inputs it needs and what each stage does
3. Work through each stage in order
4. Each stage has a clear output — verify it before moving to the next stage

## Rules

- Never skip a stage
- If a stage fails, stop and diagnose before continuing
- Workflows call out which skills to use at each stage — invoke them
```

**Step 2: Commit**

```bash
cd ~/workspace
git add workflows/CONTEXT.md
git commit -m "feat: add workflows room CONTEXT.md"
```

---

### Task 7: Write workflows/deploy-service/CONTEXT.md

**Files:**
- Create: `~/workspace/workflows/deploy-service/CONTEXT.md`

**Step 1: Write the file**

```markdown
# Workflow: Deploy Service

Builds a container image, pushes it to the registry, applies the rollout to Kubernetes, and verifies the deployment is healthy.

## Inputs

| Input | Where to get it |
|-------|----------------|
| Service name | From the task (e.g. "doable", "workstation-api") |
| Image tag | Usually `latest` unless versioning explicitly requested |
| Registry path | See table below |

## Registry paths

| Service | Image |
|---------|-------|
| doable | `registry.sammasak.dev/lab/doable-ui:latest` |
| workstation-api | `registry.sammasak.dev/lab/workstation-api:latest` |

## Stage 1: Build

**Skills:** container-workflows, credentials

```bash
# From the service directory
buildah build --isolation=chroot -t <image> .
```

Verify: `buildah images | grep <service>` — image present with recent timestamp.

## Stage 2: Push

**Skills:** credentials

```bash
buildah push --creds "admin:Harbor12345" <image>
```

Verify: image visible in Harbor UI or `skopeo inspect docker://<image>`.

## Stage 3: Apply

**Skills:** kubernetes-gitops

```bash
kubectl rollout restart deployment/<service> -n <namespace>
kubectl rollout status deployment/<service> -n <namespace>
```

Namespaces: `doable` for doable, `workstations` for workstation-api.

Verify: `kubectl rollout status` exits 0 — all pods running new image.

## Stage 4: Verify

**Skills:** verify-service

```bash
curl -sf http://<service-endpoint>/healthz
```

Or use the verify-service skill for full Tier 1+2 verification.

Verify: health endpoint returns 200, no pod restarts in `kubectl get pods -n <namespace>`.

## Output

Confirmed healthy deployment. State: all pods running, health check passing.
```

**Step 2: Commit**

```bash
cd ~/workspace
git add workflows/deploy-service/CONTEXT.md
git commit -m "feat: add deploy-service workflow"
```

---

### Task 8: Write workflows/provision-vm/CONTEXT.md and workflows/release-nixos/CONTEXT.md

**Files:**
- Create: `~/workspace/workflows/provision-vm/CONTEXT.md`
- Create: `~/workspace/workflows/release-nixos/CONTEXT.md`

**Step 1: Write provision-vm/CONTEXT.md**

```markdown
# Workflow: Provision VM

Provisions a claude-worker VM, optionally seeds it with a goal, and watches the SSE stream.

## Inputs

| Input | Notes |
|-------|-------|
| VM name | Short, lowercase, hyphenated (e.g. `build-api-v2`) |
| Goal | Optional — natural language task for the agent |

## Skills: claude-ctl

## Stage 1: Provision

```bash
claude-ctl provision <name> --goal "<goal>" --watch
```

Without a goal:
```bash
claude-ctl provision <name>
```

Verify: VM status transitions Scheduling → Starting → Booting → Ready. First boot on a new node takes ~2.5 min (image pull). Subsequent VMs ~40s.

## Stage 2: Confirm goal posted (if goal provided)

```bash
claude-ctl goals <name>
```

Verify: goal appears with status `pending` or `in_progress`.

## Stage 3: Watch (optional)

`--watch` flag streams SSE output. Press Ctrl+C to detach — VM keeps running.

## Output

Running VM with agent working on the goal. Access via `claude-ctl status <name>`.

## Teardown

```bash
claude-ctl delete <name>
```
```

**Step 2: Write release-nixos/CONTEXT.md**

```markdown
# Workflow: Release NixOS Config

Builds, switches, and pushes a NixOS configuration change.

## Inputs

| Input | Notes |
|-------|-------|
| Target host | Which host to rebuild (local or remote) |
| Change | What was modified in `~/nixos-config` |

## Skills: nix-flake-development

## Stage 1: Build (verify it compiles)

```bash
cd ~/nixos-config
nixos-rebuild build --flake .#<hostname>
```

Verify: build completes without errors. Do not switch until build passes.

## Stage 2: Switch

**Local host:**
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

**Remote host:**
```bash
just deploy <hostname>
```

Verify: `nixos-rebuild switch` exits 0. Services restart cleanly.

## Stage 3: Push

```bash
cd ~/nixos-config
git add -p   # review changes
git commit -m "nixos: <description of change>"
git push origin homelab
```

Verify: push succeeds. Flux does not manage nixos-config — push is final.

## Output

Config live on host, committed and pushed to `homelab` branch.
```

**Step 3: Commit**

```bash
cd ~/workspace
git add workflows/provision-vm/CONTEXT.md workflows/release-nixos/CONTEXT.md
git commit -m "feat: add provision-vm and release-nixos workflows"
```

---

### Task 9: Push and verify

**Step 1: Push all commits**

```bash
cd ~/workspace
git push origin main
```

**Step 2: Verify on GitHub**

```bash
gh repo view sammasak/workspace --web
```

Expected: repo visible, all files present, commit history shows 8 commits.

**Step 3: Test the workspace locally**

```bash
cd ~/workspace
claude
```

In the Claude session, say: "I want to deploy workstation-api."

Expected behaviour:
- Claude reads CLAUDE.md (map)
- Routes to `workflows/deploy-service/CONTEXT.md`
- Invokes `kubernetes-gitops`, `container-workflows`, `credentials`, `verify-service` skills
- Walks through Stage 1 → 4

**Step 4: Commit the design docs from claude-code-skills (housekeeping)**

```bash
cd ~/claude-code-skills
git add docs/plans/2026-03-18-icm-workspace-design.md docs/plans/2026-03-18-icm-workspace-impl.md
git commit -m "docs: add ICM workspace design and implementation plan"
git push origin main
```

---

## Notes for the implementer

- All files are markdown — no code, no tests, no build steps
- The skill system (claude-code-skills) keeps running in parallel — do not touch it
- To use the workspace: `cd ~/workspace && claude` — Claude reads CLAUDE.md automatically via the project context
- To add a new workflow: create `workflows/<name>/CONTEXT.md` following the stage contract pattern in deploy-service
- To add a references/ layer later: create `references/<topic>.md` and update CLAUDE.md routing table
