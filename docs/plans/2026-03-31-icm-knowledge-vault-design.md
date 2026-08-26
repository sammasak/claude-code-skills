# ICM Knowledge Vault — Design Document

**Date:** 2026-03-31
**Status:** Approved
**Repos affected:** `~/workspace`, `~/knowledge-vault`, `~/claude-code-skills`

---

## Problem

Two repos serve overlapping purposes and neither is complete:

- `~/workspace` — ICM routing (CLAUDE.md + CONTEXT.md per room) with no persistent knowledge
- `~/knowledge-vault` — Obsidian documentation vault with no routing or retrieval

Claude starts every session cold. Prior decisions, session history, and accumulated knowledge exist in the vault but are never loaded. The workspace routes correctly but carries no memory. There is no retrieval mechanism connecting the two.

---

## Solution

**One unified repo.** Merge `~/workspace` and `~/knowledge-vault` into a single git repository. The workspace IS the knowledge vault. Claude navigates it as an ICM workspace; humans browse it as an Obsidian vault; hooks retrieve from it dynamically.

Three additions on top of the existing ICM structure:

1. **INDEX.md per folder** — ICM activation signal (2–5 lines). Haiku reads these to decide relevance.
2. **Sessions room** — all human/Claude work recorded as durable artifacts.
3. **Decisions folders per project** — ADRs and RFCs live inside the project they belong to.

---

## The Two AI Files

Every folder has exactly two AI-facing files. All other files are named after their subject (Obsidian-native).

### INDEX.md — activation signal

Read by Haiku during retrieval Stage 1. Answers one question: *should this room be loaded?*

Format: 2–5 lines. Trigger topics on line 1. What to skip on line 2.

```markdown
Load this room if: NixOS, k3s, Flux GitOps, SOPS/age secrets, KubeVirt VMs, Harbor registry, homelab infrastructure.
Skip if: pure application code, writing, or personal scripts.
Key files: cluster-overview.md, runbooks/, decisions/
```

### CONTEXT.md — operational payload

Loaded after INDEX.md activates the room. Full operational instructions for Claude: commands, file paths, workflows, conventions. Existing CONTEXT.md files are unchanged — they already serve this role.

---

## Folder Structure

```
~/workspace/
├── CLAUDE.md                        ← Layer 1: routing table
│
├── homelab/                         ← Room: all infrastructure
│   ├── INDEX.md                     ← "Load if: NixOS, k3s, Flux, SOPS, KubeVirt, VMs, Harbor"
│   ├── CONTEXT.md                   ← operational instructions (existing, unchanged)
│   ├── cluster-overview.md
│   ├── hosts/
│   │   ├── acer-swift.md
│   │   └── msi-ms7758.md
│   ├── runbooks/
│   │   ├── bootstrap-cluster.md
│   │   └── add-new-host.md
│   └── decisions/
│       ├── ADR-001-flux-gitops.md
│       └── ADR-002-sops-age-encryption.md
│
├── dev/                             ← Room: all application development
│   ├── INDEX.md                     ← "Load if: doable, workstation-api, SvelteKit, Rust, app dev"
│   ├── CONTEXT.md                   ← existing dev context
│   ├── doable/
│   │   ├── INDEX.md                 ← "Load if: doable UI, SvelteKit, frontend, doable.sammasak.dev"
│   │   ├── CONTEXT.md               ← doable-specific operational context
│   │   ├── architecture.md
│   │   ├── status.md
│   │   └── decisions/
│   │       ├── ADR-001-sveltekit-framework.md
│   │       └── RFC-2026-03-auth-redesign.md
│   └── workstation-api/
│       ├── INDEX.md                 ← "Load if: workstation-api, Rust Axum, CRD, workspace API"
│       ├── CONTEXT.md
│       ├── architecture.md
│       └── decisions/
│           └── ADR-001-axum-routing.md
│
├── claude-code-skills/              ← Room: skills repo and agent system
│   ├── INDEX.md                     ← "Load if: skills, hooks, agents, ICM, claude-worker, memory"
│   ├── CONTEXT.md
│   ├── architecture.md
│   └── decisions/
│       ├── ADR-001-hook-architecture.md
│       └── RFC-2026-03-knowledge-vault-retrieval.md
│
├── workflows/                       ← Room: named multi-step pipelines
│   ├── INDEX.md                     ← "Load if: deploying a service, provisioning VM, releasing NixOS"
│   ├── CONTEXT.md                   ← existing workflow orchestration context
│   ├── deploy-service/CONTEXT.md
│   ├── provision-vm/CONTEXT.md
│   └── release-nixos/CONTEXT.md
│
├── sessions/                        ← Room: all recorded work (NEW)
│   ├── INDEX.md                     ← "Load if: looking for prior decisions, session history, what was built"
│   ├── CONTEXT.md                   ← how to create session records
│   ├── meetings/
│   │   └── YYYY-MM-DD-topic.md
│   ├── work-sessions/
│   │   └── YYYY-MM-DD-topic.md
│   └── ai-sessions/
│       └── YYYY-MM-DD-topic.md
│
├── knowledge/                       ← Room: cross-cutting reference
│   ├── INDEX.md                     ← "Load if: looking for patterns, guides, shared techniques"
│   ├── kubernetes/
│   │   ├── flux-patterns.md
│   │   └── troubleshooting.md
│   ├── nix/
│   │   └── sops-integration.md
│   └── ai-agents/
│       └── icm-methodology.md
│
├── content/                         ← Room: research, writing, learning
│   ├── INDEX.md                     ← "Load if: research, notes, writing, no code"
│   ├── CONTEXT.md
│   └── notes/
│
└── local/                           ← Room: personal scripts
    ├── INDEX.md                     ← "Load if: personal scripts, local automation"
    └── CONTEXT.md
```

---

## Session Recording

All human/Claude interactions become durable artifacts in `sessions/`.

### Three session types

**Meetings** (`sessions/meetings/YYYY-MM-DD-topic.md`)
Structured, decision-focused. Used for: human-only sync, human+Claude review, planning.

```markdown
---
date: 2026-03-31
type: meeting
attendees: [lukas, claude]
projects: [homelab, claude-code-skills]
decisions_made: [homelab/decisions/ADR-001-flux-gitops.md]
---

## Agenda
## Discussion
## Decisions Made
| Decision | Owner | ADR |
|----------|-------|-----|
| Use Flux over ArgoCD | lukas | [[homelab/decisions/ADR-001-flux-gitops]] |

## Action Items
- [ ] owner: task (due: YYYY-MM-DD)

## Links
```

**Work Sessions / Hackathons** (`sessions/work-sessions/YYYY-MM-DD-topic.md`)
Timeboxed, goal-focused. Used for: spikes, implementation sessions, hackathons.

```markdown
---
date: 2026-03-31
type: work-session
session_type: hackathon | spike | implementation | debugging
project: claude-code-skills
goal: "Design retrieval hook system"
outcome: "Two-stage Haiku workflow designed and documented"
---

## Goal + Success Criteria
## Exploration Log (timestamped)
## Key Findings
## Decisions → links to ADRs
## Next Steps
```

**AI Sessions** (`sessions/ai-sessions/YYYY-MM-DD-topic.md`)
Claude's record of what it did, decided, and learned. Written by the persist hook at session end.

```markdown
---
date: 2026-03-31
type: ai-session
project: homelab
goal: "Debug SOPS decryption failure"
outcome: "Root cause: stale age key. Fixed and documented."
files_modified: [homelab/runbooks/sops-troubleshooting.md]
decisions_made: []
---

## What Was Done
## Key Findings
## Decisions Made
## Files Created or Modified
## Open Questions
```

### Linking sessions to decisions

Any session that produces a decision links to the ADR directly:
```markdown
## Decisions Made
- Chose age over PGP for SOPS → [[homelab/decisions/ADR-002-sops-age-encryption]]
```

The ADR links back to the session:
```markdown
## Context
First discussed in [[sessions/meetings/2026-03-31-homelab-sync]]
```

---

## ADR and RFC Format

ADRs and RFCs live exclusively inside their project or domain folder under `decisions/`.
No global decisions folder — cross-cutting decisions live in the most relevant domain (e.g. `homelab/decisions/`).

**ADR naming:** `ADR-NNN-slug.md` (sequential per project, not global)

**ADR template:**
```markdown
---
status: proposed | accepted | deprecated | superseded
date: YYYY-MM-DD
supersedes: null
related: []
---

# ADR-NNN: Title

## Context
What situation led to this decision. Link to the session where it was discussed.

## Decision
What was decided. One clear sentence.

## Options Considered
| Option | Pros | Cons |
|--------|------|------|

## Consequences
Positive and negative outcomes. What becomes easier, what becomes harder.

## Links
- Discussed in: [[sessions/...]]
- Related: [[...]]
```

**RFC naming:** `RFC-YYYY-MM-slug.md` (date-based, pre-decision proposals)

RFCs precede decisions. Once accepted, an ADR is created and the RFC links to it.

---

## Two-Stage Haiku Retrieval Workflow

A separate AI workflow invoked via hook. Not tied to a fixed event — fires when Claude needs context enrichment. The workflow itself decides whether to surface anything; silence means nothing relevant was found.

### Stage 1 — Coarse scan (~0.5s)

```
Input:  current goal/context + tree ~/workspace -L 2 output
Model:  claude-haiku
Output: list of folders whose INDEX.md to read
        OR empty list (nothing relevant → hook exits silently)
```

Haiku prompt structure:
```
Current task: {goal}

Workspace structure:
{tree output}

Read the INDEX.md file for each folder that might be relevant to this task.
List only folder paths. If nothing looks relevant, output an empty list.
```

### Stage 2 — Targeted read (~1–2s)

```
Input:  INDEX.md contents from Stage 1 folders + current goal
Model:  claude-haiku
Output: summary paragraph + list of specific files worth reading
```

Haiku prompt structure:
```
Current task: {goal}

Relevant room indexes:
{INDEX.md contents}

Summarise what is relevant in 2-3 sentences.
Then list specific files the agent should read if it needs more depth.
Format:
SUMMARY: ...
FILES: path/to/file.md, path/to/other.md
```

### Hook output (what main Claude sees)

```
RELEVANT CONTEXT:
homelab/ room is relevant — you're likely working with SOPS secrets and Flux reconciliation.
Read if needed: homelab/decisions/ADR-002-sops-age-encryption.md, homelab/runbooks/bootstrap-cluster.md

dev/doable/ room is relevant — SvelteKit 2 app, builds via buildah, deploys to k8s.
Read if needed: dev/doable/architecture.md, dev/doable/status.md
```

Main Claude reads only what it decides it needs. Context stays lean.

### Quality gate

If Stage 1 returns an empty list: hook exits without printing anything.
No garbage context is ever injected. Silence is a valid output.

---

## Persist Hook

Fires at session end (Stop hook, after `check-goals.sh`). Haiku reviews what happened and writes durable artifacts back to the vault.

### What it does

1. Reads git diff + list of files modified during session
2. Haiku decides: what knowledge was produced? which session type?
3. Writes a session record to `sessions/ai-sessions/YYYY-MM-DD-topic.md`
4. If a significant decision was made: writes ADR stub to the relevant project's `decisions/` folder
5. If a new technique or pattern was discovered: updates or creates a file in `knowledge/`
6. Commits and pushes: `git add . && git commit -m "session: {date} {goal-slug}" && git push`

### Guard

Only fires when meaningful work occurred (at least one file modified, or goal marked done).
Does not fire on exploratory or failed sessions unless explicitly triggered.

---

## Git Worktree Isolation for Parallel Agents

When multiple Claude instances run in parallel (subagents or claude-worker VMs):

- Each agent gets a git worktree of `~/workspace`: `.worktrees/{agent-name}/`
- **Domain assignment**: orchestrator pre-assigns rooms to agents before dispatch
  - Agent A → `dev/doable/`
  - Agent B → `homelab/`
  - Agent C → `claude-code-skills/`
- **File naming**: agents prefix new files with `{agent-name}-YYYY-MM-DD-topic.md`
- **Shared indices**: use append-only JSONL (`knowledge-log.jsonl`) to avoid merge conflicts
- **Merge**: after all agents finish, synthesizer agent:
  1. Merges worktrees sequentially (`git merge --no-ff agent-{a,b,c}`)
  2. Reads all new session files and updates relevant INDEX.md files
  3. Commits: `session: synthesize parallel run from N agents`
  4. Removes worktrees

---

## Migration from Current State

### Phase 1 — Merge repos

1. Add `~/knowledge-vault` content into `~/workspace` under appropriate rooms:
   - `knowledge-vault/Infrastructure/` → `homelab/` (runbooks, concepts)
   - `knowledge-vault/Homelab/` → `homelab/` (architecture, decisions)
   - `knowledge-vault/Development/` → `dev/` and `claude-code-skills/`
   - `knowledge-vault/Drafts/` → `sessions/work-sessions/` or appropriate room
2. Archive `~/knowledge-vault` repo (keep remote, add redirect note)
3. Point Obsidian at `~/workspace`

### Phase 2 — Add INDEX.md files

Create `INDEX.md` in every folder (root, each room, each project subfolder).
2–5 lines each. This is the only new file type introduced.

### Phase 3 — Wire hooks

New hooks in `~/claude-code-skills/hooks/`:
- `retrieve-context.sh` — two-stage Haiku retrieval workflow
- Extend `extract-instincts.sh` → becomes the persist hook

Wire in `mcp.nix` via Home Manager:
- `retrieve-context.sh` → `UserPromptSubmit` hook (fires on new goal/message)
- Persist → existing Stop hook chain (after `check-goals.sh`)

### Phase 4 — Migrate knowledge-vault skill

Update `~/claude-code-skills/skills/knowledge-vault/SKILL.md` to reflect the merged structure. The skill now documents both how to navigate the workspace AND how to create session records and decisions.

---

## Success Criteria

- Claude navigates to the correct room without being told
- Retrieval hook surfaces relevant context within 3s on a cold session
- Retrieval hook stays silent when nothing is relevant (no garbage injection)
- Session records are created automatically at session end
- ADRs and RFCs link bidirectionally to sessions
- Obsidian opens `~/workspace` and all files are browsable and well-named
- Parallel agent runs produce non-conflicting knowledge artifacts
- INDEX.md quality drives retrieval quality — well-maintained INDEX.md = accurate retrieval
