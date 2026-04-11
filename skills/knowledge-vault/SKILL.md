---
name: knowledge-vault
description: Use when asked to document work, record decisions, create session records, write ADRs or RFCs, or update knowledge notes in ~/workspace.
---

# Knowledge Vault

`~/workspace` is an ICM workspace and Obsidian knowledge vault. See `~/workspace/CLAUDE.md` for the full routing map and room structure.

## Naming Conventions

| Type | Pattern | Location |
|------|---------|----------|
| Work session | `YYYY-MM-DD-topic.md` | `sessions/work-sessions/` |
| Meeting | `YYYY-MM-DD-topic.md` | `sessions/meetings/` |
| ADR | `ADR-NNN-slug.md` | `<project>/decisions/` |
| RFC | `RFC-YYYY-MM-slug.md` | `<project>/decisions/` — pre-decision; link to ADR once accepted |
| Knowledge | subject-named | `knowledge/<domain>/` |

## Session Record Frontmatter

```yaml
---
date: YYYY-MM-DD
type: work-session  # meeting | ai-session
project: homelab
goal: "one sentence"
outcome: "result"
---
```

## ADR Frontmatter

```yaml
---
status: accepted  # proposed | accepted | superseded
date: YYYY-MM-DD
supersedes: null
related: []
---
```

Required sections: **Context**, **Decision** (one sentence), **Options Considered** (table), **Consequences**, **Links**.

## INDEX.md and CONTEXT.md

AI-facing only — do not rename:
- `INDEX.md` — 2–5 lines, activation signal for Haiku retrieval
- `CONTEXT.md` — full operational instructions for Claude

## Always Sync After Changes

```bash
cd ~/workspace && git add . && git commit -m "docs: <change>" && git push
```
