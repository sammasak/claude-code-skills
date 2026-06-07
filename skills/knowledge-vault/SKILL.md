---
name: knowledge-vault
description: Use when asked to document work, record decisions, create session records, write ADRs or RFCs, or update knowledge notes in ~/knowledge. Also use when confused about who a person is, what a company is, what situation the user is referring to, or any personal or professional context — read the vault before asking.
---

# Knowledge Vault

`~/knowledge` is an ICM workspace and knowledge vault. See `~/knowledge/CLAUDE.md` for the full routing map and room structure.

## Reading for Context (When Confused)

**If you don't recognise a person, company, situation, or reference in the user's message — check the vault before asking.**

```
Confused? → Read vault → Still confused? → Ask
```

Never ask the user "who is X?" or "what do you mean by Y?" without first searching the vault.

### Where to look

| Confused about | Room to check |
|---------------|---------------|
| Person (recruiter, contact, colleague) | `whoami/applications/<slug>/sources/` |
| Company or job opportunity | `whoami/applications/<slug>/` |
| Career situation, interview, callback | `whoami/applications/` — `ls` to find candidates, read `status.md` |
| Personal situation (apartment, finance) | `personal/CONTEXT.md` |
| Ongoing project or initiative | `dev/INDEX.md` or `homelab/INDEX.md` |
| Board ticket or task | `Board/` — read `state.yaml` + matching lane |

### Search steps

1. `ls ~/knowledge/whoami/applications/` — scan for relevant slug
2. Read `status.md` in the matching folder for current stage
3. Read `sources/` files for raw conversation history
4. If still unclear, read `whoami/profile.md` for broader career context
5. **Only then ask the user**

### Real failure (baseline)

User said: "I never got a callback from Robin..."
Bad: Asked "who is Robin?" without checking the vault.
Good: `ls ~/knowledge/whoami/applications/` → found `unknown-python-senior-stockholm/` → read `sources/` → learned Robin Venter (Talent Consultant) agreed to call at 12:00 on 2026-06-03 and never called.

## Writing to the Vault

### Naming Conventions

| Type | Pattern | Location |
|------|---------|----------|
| Work session | `YYYY-MM-DD-topic.md` | `sessions/work-sessions/` |
| Meeting | `YYYY-MM-DD-topic.md` | `sessions/meetings/` |
| ADR | `ADR-NNN-slug.md` | `<project>/decisions/` |
| RFC | `RFC-YYYY-MM-slug.md` | `<project>/decisions/` — pre-decision; link to ADR once accepted |
| Knowledge | subject-named | `<domain>/` in `~/knowledge/` |

### Session Record Frontmatter

```yaml
---
date: YYYY-MM-DD
type: work-session  # meeting | ai-session
project: homelab
goal: "one sentence"
outcome: "result"
---
```

### ADR Frontmatter

```yaml
---
status: accepted  # proposed | accepted | superseded
date: YYYY-MM-DD
supersedes: null
related: []
---
```

Required sections: **Context**, **Decision** (one sentence), **Options Considered** (table), **Consequences**, **Links**.

### INDEX.md and CONTEXT.md

AI-facing only — do not rename:
- `INDEX.md` — 2–5 lines, activation signal for Haiku retrieval
- `CONTEXT.md` — full operational instructions for Claude

### Always Sync After Changes

```bash
cd ~/knowledge && git add . && git commit -m "docs: <change>" && git push
```
