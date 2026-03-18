# ICM Workspace Repo Design

**Date:** 2026-03-18
**Status:** Approved
**Repo:** `sammasak/workspace` (private), cloned to `~/workspace`

## Context

Jake Van Clief's Interpreted Context Methodology (ICM) uses filesystem structure as an orchestration layer. Instead of complex agent frameworks, numbered folders and markdown files tell the AI where it is, what to do, and where to put work. Three layers:

- **Layer 1:** `CLAUDE.md` at root — always-loaded map and routing table (~800 tokens)
- **Layer 2:** Per-workspace `CONTEXT.md` files — what each room is for, its process, what to load
- **Layer 3:** Skills/tools — selectively loaded per workspace, not globally

This repo adopts that pattern as a standalone workspace to run in parallel with `claude-code-skills` (dual run). The goal is to evaluate ICM performance vs the skills injection system before any migration.

## Structure

```
~/workspace/
├── CLAUDE.md                    # Layer 1: always-loaded map + routing table
├── homelab/
│   └── CONTEXT.md               # k8s, nix, flux, VM ops, SOPS
├── dev/
│   └── CONTEXT.md               # doable, workstation-api, app development
├── local/
│   └── CONTEXT.md               # personal scripts, tools, local automation
├── content/
│   └── CONTEXT.md               # notes, docs, writing, research
└── workflows/
    ├── CONTEXT.md               # what a workflow is, how to run one
    ├── deploy-service/
    │   └── CONTEXT.md           # build → push → apply → verify
    ├── provision-vm/
    │   └── CONTEXT.md           # claude-ctl + goal seeding
    └── release-nixos/
        └── CONTEXT.md           # nixos-rebuild + switch + push
```

## Design Decisions

**Why B + C (flat + workflows-first):**
- Start minimal (Option C) — no `references/` folder yet, add when duplication becomes a real problem
- Explicit `workflows/` room (Option B) — named reusable pipelines are first-class from day one
- Avoids over-engineering before the pattern is proven

**Dual run with claude-code-skills:**
- Skills still inject via description-matching as before
- Workspace provides navigation and sequencing; skills provide domain knowledge
- Workflow CONTEXT.md files can reference skills explicitly (e.g. "use kubernetes-gitops skill for the apply step")
- No Home Manager wiring yet — local only, `cd ~/workspace && claude`

**What goes in each workspace:**

| Workspace | Content |
|-----------|---------|
| `homelab/` | Cluster state, Flux reconciliation, NixOS rebuilds, SOPS secrets, VM management |
| `dev/` | doable SvelteKit app, workstation-api Rust service, feature work, deployments |
| `local/` | Personal scripts, tool configs, local automation, one-off tasks |
| `content/` | Research notes, docs, writing, Skool/learning content |
| `workflows/` | Named multi-step pipelines that span workspaces |

**Initial workflows to implement:**

| Workflow | Steps |
|----------|-------|
| `deploy-service` | build → push to registry → kubectl apply → verify-service |
| `provision-vm` | claude-ctl provision → seed goal → watch SSE stream |
| `release-nixos` | nixos-rebuild build → switch → push nixos-config |

## CLAUDE.md Token Budget

Target ~800 tokens. Contents:
- One-line description of each workspace and when to use it
- Routing table: task → workspace → workflow (if applicable)
- Which skills to load alongside each workspace
- Naming conventions for any files created

## Success Criteria

- Claude navigates to the correct workspace without being explicitly told
- Multi-step workflows run with a single prompt ("deploy workstation-api")
- Token usage per task is lower than equivalent skills-only sessions
- Can be evaluated subjectively after 2 weeks of parallel use
