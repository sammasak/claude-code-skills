---
name: kanban-draft-adr
description: >-
  Draft an Architecture Decision Record from a completed or completing kanban ticket. Captures the decision, context, options, and consequences so institutional knowledge is not lost after the work is done.
---

Draft an Architecture Decision Record from a completed or completing kanban ticket. Captures the decision, context, options, and consequences so institutional knowledge is not lost after the work is done.

## When to use

When a ticket is being moved to `completed` AND any of:
- `type: rfc`
- `domain:` is `infra`, `platform`, or `architecture`
- `goal:` contains any of: replace, migrate, adopt, reject, redesign, retire, upgrade

Do NOT draft an ADR for routine chores, minor fixes, or doc-only tickets.

## Inputs

- Ticket file path (required)
- PR URL (optional — read the diff for richer consequences)

## Process

### Step 1 — Determine ADR location and number

Map ticket `domain:` to decisions directory:
- `infra`, `platform`, `architecture`: `~/workspace/homelab/decisions/`
- `apps`: `~/workspace/dev/<app-name>/decisions/` (infer app from ticket title)
- `skills`: `~/workspace/claude-code-skills/decisions/`
- Default: `~/workspace/homelab/decisions/`

Find the next ADR number:
```bash
DECISIONS_DIR=<mapped-path>
LAST=$(ls "$DECISIONS_DIR" | grep "^ADR-" | sort -V | tail -1)
LAST_N=$(echo "$LAST" | grep -oP 'ADR-\K\d+' || echo "000")
NEXT=$(printf "%03d" $((10#$LAST_N + 1)))
```

### Step 2 — Read the ticket

From the ticket file extract:
- `title` → ADR title
- `evidence` → Context section material
- `goal` → understand what was done
- `dod` → each passing check becomes a Consequence/Benefit bullet
- `impl_pr_url` → link in the Links section

If `impl_pr_url` is set and not `~`:
```bash
gh pr view <impl_pr_url> --json title,body,additions,deletions,changedFiles \
  | jq '{title,body,additions,deletions,files: .changedFiles}'
```
Use the PR body and changed files to enrich the Options Considered and Consequences sections.

### Step 3 — Draft the ADR

Write `$DECISIONS_DIR/ADR-${NEXT}-<kebab-case-title>.md`:

```markdown
---
status: accepted
date: YYYY-MM-DD
supersedes: null
related:
  - <ticket-id>
---

# ADR-NNN: <Title from ticket>

## Context

<Why this decision was needed. Pull from ticket evidence: field.
Include the observable problem: what was broken, out of date, or missing.
2-4 paragraphs.>

## Decision

<One sentence. What was done. Start with a verb: "Upgrade", "Replace", "Add", "Remove".>

## Options Considered

| Option | Description | Verdict |
|---|---|---|
| **A. <What was done>** | <brief description> | **Chosen** |
| **B. Status quo** | Keep existing behaviour / no action | Rejected — <one-line reason> |

<Add more rows if the ticket goal or PR body mentions alternatives explicitly.>

## Consequences

**Benefits:**
<One bullet per passing DoD check. Each bullet names what is now guaranteed.>
- `<dod.check command>` passes: <what this means in plain English>

**Trade-offs:**
<Negatives, caveats, follow-on work created by this decision. If none, write "None identified.">

## Links

- Ticket: <ticket-id>
- PR: <impl_pr_url or "none">
```

### Step 4 — Commit

```bash
git -C ~/workspace add "$DECISIONS_DIR/ADR-${NEXT}-<slug>.md"
git -C ~/workspace commit -m "docs: ADR-${NEXT} - <title>"
git -C ~/workspace push
```
