---
name: knowledge-vault
description: Manage documentation in ~/workspace knowledge vault — create session records, ADRs, RFCs, and knowledge notes. Use when asked to document work, record decisions, or update vault content.
---

# Knowledge Vault

`~/workspace` is a unified ICM workspace and Obsidian knowledge vault.
All documentation, decisions, and session records live here alongside the routing layer.

## Vault Structure

```
~/workspace/
├── CLAUDE.md              ← routing table
├── homelab/               ← infrastructure docs
│   ├── INDEX.md           ← activation signal
│   ├── CONTEXT.md         ← operational context
│   ├── runbooks/          ← operational runbooks
│   └── decisions/         ← homelab ADRs and RFCs
├── dev/
│   ├── doable/decisions/  ← doable ADRs and RFCs
│   └── workstation-api/decisions/
├── claude-code-skills/decisions/
├── sessions/
│   ├── meetings/          ← meeting notes
│   ├── work-sessions/     ← spikes, hackathons, implementations
│   └── ai-sessions/       ← Claude session records (auto-written by hook)
└── knowledge/             ← cross-cutting reference
```

## File Naming Conventions

- Session files: `YYYY-MM-DD-topic.md` (date-prefixed)
- ADRs: `ADR-NNN-slug.md` (sequential per project)
- RFCs: `RFC-YYYY-MM-slug.md` (date-prefixed, pre-decision proposals)
- All other files: named after their subject (e.g. `cluster-overview.md`, `sops-integration.md`)

## Creating a Session Record

For meetings and work sessions, create the file manually:

```bash
VAULT=~/workspace
DATE=$(date +%Y-%m-%d)
TYPE=meetings  # or work-sessions
TOPIC="homelab-planning-sync"
FILE="$VAULT/sessions/$TYPE/$DATE-$TOPIC.md"
```

Frontmatter:
```yaml
---
date: 2026-03-31
type: meeting          # or work-session, ai-session
attendees: [lukas]     # for meetings
project: homelab       # primary project
goal: "one sentence"   # for work-sessions
outcome: "result"      # fill in at end
---
```

Commit after writing:
```bash
cd ~/workspace && git add sessions/ && git commit -m "session: $DATE $TOPIC" && git push
```

## Creating an ADR

ADRs live inside their project room under decisions/:

```bash
VAULT=~/workspace
PROJECT=homelab   # or dev/doable, dev/workstation-api, claude-code-skills
NUM=001
SLUG="use-flux-for-gitops"
FILE="$VAULT/$PROJECT/decisions/ADR-$NUM-$SLUG.md"
```

ADR frontmatter:
```yaml
---
status: accepted
date: 2026-03-31
supersedes: null
related: []
---
```

Required sections: Context, Decision (one sentence), Options Considered (table), Consequences, Links.

## Creating an RFC

RFC = pre-decision proposal. Name: `RFC-YYYY-MM-slug.md` in same decisions/ folder.
Once accepted, create the ADR and link from the RFC.

## Syncing Changes

Always commit and push after vault changes:
```bash
cd ~/workspace
git add .
git commit -m "docs: <describe change>"
git push
```

## INDEX.md and CONTEXT.md

These are the only AI-facing files. Do not rename them:
- `INDEX.md` — 2-5 lines, activation signal for Haiku retrieval
- `CONTEXT.md` — full operational instructions for Claude

All other files are named after their subject (human-readable, Obsidian-native).
