# Kanban Skill Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create four kanban workflows in `~/workspace/workflows/`, export them to `~/claude-code-skills/skills/` as SKILL.md files, extend the ticket schema with epic/dependency fields, and wire the scrum master to auto-draft ADRs and emit status reports.

**Architecture:** Workflows live canonically in `~/workspace/workflows/kanban-*/CONTEXT.md` (plain markdown, no frontmatter, consistent with all existing workflows). An export script in `~/workspace/workflows/hooks/export-skills.sh` wraps each opted-in CONTEXT.md in SKILL.md frontmatter and writes it to `~/claude-code-skills/skills/`. The scrum master reads CONTEXT.md files directly from the workspace canonical copy; the Skill tool uses the exported SKILL.md.

**Tech Stack:** Bash, markdown, yq (for YAML parsing in scrum master), POSIX shell

**Spec:** `~/claude-code-skills/docs/plans/2026-05-07-kanban-skill-suite-design.md`

---

## File map

| Action | Path |
|---|---|
| Create | `~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md` |
| Create | `~/workspace/workflows/kanban-groom-ticket/CONTEXT.md` |
| Create | `~/workspace/workflows/kanban-draft-adr/CONTEXT.md` |
| Create | `~/workspace/workflows/kanban-status/CONTEXT.md` |
| Create | `~/workspace/workflows/hooks/export-skills.sh` |
| Modify | `~/workspace/workflows/INDEX.md` |
| Modify | `~/knowledge-vault/Meta/templates/ticket.md` |
| Modify | `~/homelab-improvement-loop/scrum-master/GOAL.md` (Step 4 loop + new Steps 9-10) |
| Generate | `~/claude-code-skills/skills/kanban-adr-to-tickets/SKILL.md` |
| Generate | `~/claude-code-skills/skills/kanban-groom-ticket/SKILL.md` |
| Generate | `~/claude-code-skills/skills/kanban-draft-adr/SKILL.md` |
| Generate | `~/claude-code-skills/skills/kanban-status/SKILL.md` |

---

## Task 1: Export script

**Files:**
- Create: `~/workspace/workflows/hooks/export-skills.sh`

- [ ] **Step 1.1: Write the export script**

```bash
cat > ~/workspace/workflows/hooks/export-skills.sh << 'SCRIPT'
#!/usr/bin/env bash
# Export workspace workflows to claude-code-skills SKILL.md files.
# Workflows opt in by including "<!-- export:skill -->" on the first line of CONTEXT.md.
set -euo pipefail

WORKFLOWS="${HOME}/workspace/workflows"
SKILLS="${HOME}/claude-code-skills/skills"

exported=0
for dir in "$WORKFLOWS"/*/; do
  name=$(basename "$dir")
  ctx="${dir}CONTEXT.md"
  [ -f "$ctx" ] || continue
  # Opt-in marker on first line
  head -1 "$ctx" | grep -q "<!-- export:skill -->" || continue

  # Extract description: first non-empty line that isn't the marker or a heading
  description=$(grep -v "<!-- export:skill -->" "$ctx" | grep -m1 "^[^#[:space:]]" | head -1)
  [ -n "$description" ] || description="$name workflow"

  mkdir -p "$SKILLS/$name"
  {
    printf -- "---\nname: %s\ndescription: >-\n  %s\n---\n\n" "$name" "$description"
    # Strip the first line (marker) from the content
    tail -n +2 "$ctx"
  } > "$SKILLS/$name/SKILL.md"

  echo "Exported: $name → $SKILLS/$name/SKILL.md"
  exported=$((exported + 1))
done

echo "Done. Exported $exported skill(s)."
SCRIPT
chmod +x ~/workspace/workflows/hooks/export-skills.sh
```

- [ ] **Step 1.2: Verify the script is executable and runs without errors on an empty set**

```bash
~/workspace/workflows/hooks/export-skills.sh
```
Expected output:
```
Done. Exported 0 skill(s).
```

- [ ] **Step 1.3: Commit**

```bash
cd ~/workspace
git add workflows/hooks/export-skills.sh
git commit -m "feat: add export-skills.sh — export workflows to claude-code-skills"
```

---

## Task 2: Ticket template extension

**Files:**
- Modify: `~/knowledge-vault/Meta/templates/ticket.md`

- [ ] **Step 2.1: Verify current template contents**

```bash
cat ~/knowledge-vault/Meta/templates/ticket.md
```

- [ ] **Step 2.2: Add epic/dependency/planning fields to the YAML frontmatter block**

Open `~/knowledge-vault/Meta/templates/ticket.md`. After the `blocks: []` line (if it exists) or after `labels: []`, add the following block. If any of these fields already exist, skip adding them.

The full updated frontmatter section should read:

```yaml
---
epic: ~                  # ID of parent epic ticket, e.g. TICKET-2026-05-07-platform-001
ticket_id: # PREFIX-###
title: # Short, actionable title
assignee: # unassigned | username
status: todo  # todo | in-progress | blocked | review | done
priority: medium  # critical | high | medium | low
repositories: []  # [nixos-config, homelab-gitops, knowledge-vault]
parent_ticket: ~         # Direct parent ticket ID (for sub-tasks within an epic)
blocks: []               # Ticket IDs that cannot start until this one completes
blocked_by: []           # Ticket IDs that must complete before this one can start
created: {{date}}
updated: {{date}}
estimated_effort: ~      # e.g. "2-4 hours", "1 day", "1 week"
labels: []               # e.g. [rust, k8s, auth, breaking-change]
---
```

- [ ] **Step 2.3: Verify the template is valid YAML**

```bash
head -25 ~/knowledge-vault/Meta/templates/ticket.md | yq eval '.' - 2>&1 | grep -v "^null"
```
Expected: no errors printed.

- [ ] **Step 2.4: Commit**

```bash
cd ~/knowledge-vault
git add Meta/templates/ticket.md
git commit -m "feat: add epic, blocked_by, blocks, estimated_effort fields to ticket template"
git push
```

---

## Task 3: kanban-adr-to-tickets workflow

**Files:**
- Create: `~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md`

- [ ] **Step 3.1: Create the directory**

```bash
mkdir -p ~/workspace/workflows/kanban-adr-to-tickets
```

- [ ] **Step 3.2: Write CONTEXT.md**

```bash
cat > ~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md << 'EOF'
<!-- export:skill -->
Break an ADR's Implementation Plan section into per-phase Board tickets in ~/knowledge-vault/Board/backlog/. Each ticket is fully self-contained: a worker completes it without reading the ADR.

## When to use

When an ADR has a `## Implementation Plan` section with multiple phases that need to be tracked as individual kanban tickets. The ADR's current single parent ticket becomes the `epic:` reference on each generated ticket.

## Inputs

- ADR file path (required)
- Epic/parent ticket ID (optional — set in generated tickets' `epic:` field)
- Domain override (optional — inferred from ADR content if omitted)

## Process

### Step 1 — Read the ADR

Read the full ADR file. Locate `## Implementation Plan`. Identify all phases (headings starting with `### Phase N` or numbered `### N.`). For each phase capture:
- Phase title and description text
- All numbered implementation steps (verbatim, including bash commands)
- The DoD `yaml` block at the bottom of the phase (if present)

### Step 2 — Check idempotency

Before writing anything, check for existing phase tickets:

```bash
grep -r "epic: <parent-ticket-id>" ~/knowledge-vault/Board/ --include="*.md" -l 2>/dev/null
```

If tickets already exist with this epic, list them and exit. Do not create duplicates.

### Step 3 — Assign ticket IDs

Find the next available sequential ID for the domain:

```bash
DOMAIN=<inferred-or-provided-domain>
TODAY=$(date +%Y-%m-%d)
# Count across ALL board columns to avoid ID collisions
ALL=$(find ~/knowledge-vault/Board/ -name "TICKET-${TODAY}-${DOMAIN}-*.md" 2>/dev/null | wc -l)
# IDs for N phases: $((ALL+1)), $((ALL+2)), ..., $((ALL+N))
```

Assign IDs sequentially: `TICKET-$TODAY-$DOMAIN-$(printf "%03d" $((ALL+1)))`, etc.

### Step 4 — Write ticket files

For each phase write `~/knowledge-vault/Board/backlog/TICKET-<id>.md`.

Required frontmatter fields:

```yaml
---
id: TICKET-YYYY-MM-DD-<domain>-NNN
type: task
title: "<ADR short title> — Phase N: <phase title>"
domain: <domain>
priority: medium
status: backlog
created: YYYY-MM-DD
approved: ~
worker_started: ~
review_started: ~
implemented: ~
assigned_worker: ~
worker_type: ~
worker_exit_file: ~
proposal_pr_url: ~
impl_pr_url: ~
epic: <parent-ticket-id or ~>
parent_ticket: ~
blocks: [<next-phase-ticket-id or empty list>]
blocked_by: [<prev-phase-ticket-id or empty list>]
estimated_effort: ~
labels: []
goal: |
  ## Context
  <2-3 sentences from the ADR Context section explaining WHY this phase exists.
  The worker must understand the motivation without reading the ADR.>

  Full ADR: <absolute path to ADR file>

  ## Steps
  <ALL numbered steps from the ADR phase verbatim. Include every bash command.
  Expand any cross-references ("see step N") into the full instruction.
  A worker MUST be able to complete this ticket without opening the ADR.>

  ## Exit protocol
  After completing all steps, run each DoD check below.
  If ALL checks pass: write 0 to $WORKER_EXIT_FILE.
  If ANY check fails: write 1 to $WORKER_EXIT_FILE and append ## DoD Failures
  to this ticket file listing which checks failed and their output.

dod:
  - check: "<shell command that exits 0 on success>"
    description: "<what this verifies>"
  # One entry per DoD check from the ADR phase.
  # Every check MUST be a shell command. No prose-only items.

evidence: |
  Generated by kanban-adr-to-tickets on YYYY-MM-DD.
  Source: <ADR file path>, Phase N — <phase title>
---
```

### Step 5 — Set dependency chain

- Phase 1: `blocked_by: []`, `blocks: [<phase-2-id>]`
- Phase N (middle): `blocked_by: [<phase-N-1-id>]`, `blocks: [<phase-N+1-id>]`
- Phase last: `blocked_by: [<phase-last-1-id>]`, `blocks: []`

### Step 6 — Commit and open PR

```bash
cd ~/knowledge-vault
git checkout -b ticket/adr-<slug>-breakdown
git add Board/backlog/
git commit -m "board: break <ADR title> into <N> phase tickets"
git push -u origin ticket/adr-<slug>-breakdown
gh pr create --repo sammasak/knowledge-vault \
  --title "ticket: <ADR title> phase breakdown (<N> tasks)" \
  --body "Breaks <ADR path> into <N> phase tickets.
Phase 1 can start immediately. Each subsequent phase is blocked_by the previous.
Generated by kanban-adr-to-tickets workflow."
```

## Constraints

- `goal:` MUST be self-contained. Never write "see ADR for details." Inline every step.
- Every `dod:` check MUST be a shell command. Prose-only checks are not acceptable.
- Phase tickets are ordered: each `blocked_by` the previous phase's ticket ID.
- The scrum master skips dispatch of a ticket if any ID in `blocked_by` is not in `Board/completed/`.
EOF
```

- [ ] **Step 3.3: Verify the file was written correctly**

```bash
head -5 ~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md
```
Expected first line: `<!-- export:skill -->`

- [ ] **Step 3.4: Run export script — verify SKILL.md is generated**

```bash
~/workspace/workflows/hooks/export-skills.sh
```
Expected:
```
Exported: kanban-adr-to-tickets → /home/lukas/claude-code-skills/skills/kanban-adr-to-tickets/SKILL.md
Done. Exported 1 skill(s).
```

```bash
head -6 ~/claude-code-skills/skills/kanban-adr-to-tickets/SKILL.md
```
Expected:
```
---
name: kanban-adr-to-tickets
description: >-
  Break an ADR's Implementation Plan section into per-phase Board tickets...
---
```

---

## Task 4: kanban-groom-ticket workflow

**Files:**
- Create: `~/workspace/workflows/kanban-groom-ticket/CONTEXT.md`

- [ ] **Step 4.1: Create directory and write CONTEXT.md**

```bash
mkdir -p ~/workspace/workflows/kanban-groom-ticket
cat > ~/workspace/workflows/kanban-groom-ticket/CONTEXT.md << 'EOF'
<!-- export:skill -->
Take a vague or under-specified Board backlog ticket and flesh it out into a fully actionable specification with concrete implementation steps and executable DoD checks.

## When to use

When a ticket in `~/knowledge-vault/Board/backlog/` has any of:
- `goal:` fewer than 8 lines
- `dod:` empty or contains no shell commands (prose-only items)
- `type:` is `~`
- `priority:` is `~`

A ticket is **groomed** when ALL of:
- `goal:` has numbered steps with at least one concrete bash command
- `dod:` has at least 2 items with shell commands that exit 0 on success
- `type:` and `priority:` are set

## Process

### Step 1 — Identify ungroomed tickets

```bash
for f in ~/knowledge-vault/Board/backlog/*.md; do
  [ "$(basename "$f")" = ".gitkeep" ] && continue
  lines=$(awk '/^goal:/,/^dod:/' "$f" | grep -v "^dod:" | wc -l)
  dod_checks=$(grep -c "check:" "$f" 2>/dev/null || echo 0)
  type_set=$(grep "^type:" "$f" | grep -v "~" | wc -l)
  priority_set=$(grep "^priority:" "$f" | grep -v "~" | wc -l)
  if [ "$lines" -lt 8 ] || [ "$dod_checks" -lt 2 ] || [ "$type_set" -eq 0 ] || [ "$priority_set" -eq 0 ]; then
    echo "$f"
  fi
done
```

### Step 2 — Research context for each ungroomed ticket

For each ticket:
1. Read `evidence:` to understand why it was created
2. Read `title:` and any existing `goal:` text
3. Check domain:
   - `infra`: run `kubectl get all -A | head -20` and read relevant manifests in `~/homelab-gitops/`
   - `apps`: read the affected Deployment/Service manifests
   - `skills`: read `~/claude-code-skills/skills/` for relevant existing skills
   - `docs`: read the relevant knowledge-vault section
4. Identify what "done" looks like — what must be verifiably true when the ticket completes?

### Step 3 — Write the groomed ticket

Rewrite the `goal:` field:

```
## Context
<2-3 sentences explaining why this work matters. Draw from evidence: field.>

## Steps
1. <Concrete first step. Include the actual bash command or file edit needed.>
2. <Next step.>
...

## Verification
Run the DoD checks below before marking done.
```

Write `dod:` with concrete shell checks. EVERY check must be a shell command.
If a DoD item genuinely requires human judgment:
```yaml
- check: "test -f /tmp/human-verified-<ticket-id> || (echo 'HUMAN GATE: verify X then: touch /tmp/human-verified-<ticket-id>' && exit 1)"
  description: "Human verification gate: confirm X is correct"
```

Set `type:` to one of: `task` | `rfc` | `chore` | `incident`
Set `priority:` to one of: `critical` | `high` | `medium` | `low`
Set `estimated_effort:` to a human-readable estimate: `"1-2 hours"`, `"half day"`, `"1-2 days"`

### Step 4 — Commit

```bash
TICKET_ID=$(grep "^id:" <ticket-file> | awk '{print $2}')
git -C ~/knowledge-vault add Board/backlog/<ticket-filename>
git -C ~/knowledge-vault commit -m "board: groom ${TICKET_ID} — add goal and DoD"
git -C ~/knowledge-vault push
```
EOF
```

- [ ] **Step 4.2: Verify and export**

```bash
head -3 ~/workspace/workflows/kanban-groom-ticket/CONTEXT.md
~/workspace/workflows/hooks/export-skills.sh
ls ~/claude-code-skills/skills/kanban-groom-ticket/SKILL.md
```
Expected: file exists.

---

## Task 5: kanban-draft-adr workflow

**Files:**
- Create: `~/workspace/workflows/kanban-draft-adr/CONTEXT.md`

- [ ] **Step 5.1: Create directory and write CONTEXT.md**

```bash
mkdir -p ~/workspace/workflows/kanban-draft-adr
cat > ~/workspace/workflows/kanban-draft-adr/CONTEXT.md << 'EOF'
<!-- export:skill -->
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
git -C ~/workspace commit -m "docs: ADR-${NEXT} — <title>"
git -C ~/workspace push
```
EOF
```

- [ ] **Step 5.2: Verify and export**

```bash
head -3 ~/workspace/workflows/kanban-draft-adr/CONTEXT.md
~/workspace/workflows/hooks/export-skills.sh
ls ~/claude-code-skills/skills/kanban-draft-adr/SKILL.md
```
Expected: file exists.

---

## Task 6: kanban-status workflow

**Files:**
- Create: `~/workspace/workflows/kanban-status/CONTEXT.md`

- [ ] **Step 6.1: Create directory and write CONTEXT.md**

```bash
mkdir -p ~/workspace/workflows/kanban-status
cat > ~/workspace/workflows/kanban-status/CONTEXT.md << 'EOF'
<!-- export:skill -->
Generate a board status report from the current kanban board state. Writes to ~/knowledge-vault/Board/status-latest.md, commits, and posts a summary to ntfy.

## When to use

On demand for a current board snapshot, or at the end of each scrum master run.

## Process

### Step 1 — Read board state

```bash
BOARD=~/knowledge-vault/Board
for col in backlog waiting in-progress review verifying needs-info on-hold blocked failed completed; do
  count=$(find "$BOARD/$col/" -name "*.md" ! -name ".gitkeep" 2>/dev/null | wc -l)
  printf "%s: %s\n" "$col" "$count"
done
```

For in-progress tickets: read each file, extract `assigned_worker`, `worker_started`, `title`.
Compute elapsed: `$(( ($(date +%s) - $(date -d "$WORKER_STARTED" +%s 2>/dev/null || echo $(date +%s))) / 60 ))m`

For needs-info and blocked: read `title` and first line of `evidence:`.

For completed-today: `git -C ~/knowledge-vault log --since="24 hours ago" --name-only --diff-filter=A --pretty="" -- Board/completed/ | grep "\.md$"`

For failed: read `title` and `retry_count`.

### Step 2 — Read capacity from state.yaml

```bash
MAX=$(grep "max_concurrent_workers:" ~/knowledge-vault/Board/state.yaml | awk '{print $2}')
```

### Step 3 — Write report

Write `~/knowledge-vault/Board/status-latest.md`:

```markdown
# Board Status — YYYY-MM-DD HH:MM

## In Progress (<current>/<max> capacity)
<For each in-progress ticket:>
- **TICKET-id** — <title> (worker: `<assigned_worker>`, <elapsed>m elapsed)

## Queued — waiting (<n>)
<For each waiting ticket, sorted critical→low:>
- **TICKET-id** [<priority>] — <title>

## Needs Info (<n>)
<For each needs-info ticket:>
- **TICKET-id** — <title>
  > <first line of evidence>

## Blocked (<n>)
<For each blocked ticket:>
- **TICKET-id** — <title> — blocked by: <blocked_by values>

## Completed Today (<n>)
<For each ticket added to completed/ in last 24h:>
- ✓ **TICKET-id** — <title>

## Failed (<n>)
<For each failed ticket:>
- ✗ **TICKET-id** — <title> (retry <retry_count>/3)

## Backlog (<n> total)
```

### Step 4 — Commit and notify

```bash
git -C ~/knowledge-vault add Board/status-latest.md
git -C ~/knowledge-vault commit -m "board: status update $(date -Iseconds)" || true
git -C ~/knowledge-vault push

# Post first 20 lines to ntfy
curl -s \
  -H "Title: Board Status $(date +%Y-%m-%d\ %H:%M)" \
  -H "Tags: clipboard" \
  -d "$(head -20 ~/knowledge-vault/Board/status-latest.md)" \
  http://10.43.19.253/homelab-improvements || true
```
EOF
```

- [ ] **Step 6.2: Verify and export**

```bash
head -3 ~/workspace/workflows/kanban-status/CONTEXT.md
~/workspace/workflows/hooks/export-skills.sh
ls ~/claude-code-skills/skills/kanban-status/SKILL.md
```
Expected: 4 total skills exported.

---

## Task 7: Update workflows INDEX.md

**Files:**
- Modify: `~/workspace/workflows/INDEX.md`

- [ ] **Step 7.1: Add four new rows to the Available workflows table**

Open `~/workspace/workflows/INDEX.md`. Find the table that lists all workflows. Add four new rows after the `to-issues` row:

```markdown
| `kanban-adr-to-tickets/` | Break an ADR's Implementation Plan into per-phase Board tickets | Decomposing a large ADR into kanban work items |
| `kanban-groom-ticket/` | Flesh out a vague backlog ticket with concrete steps and executable DoD | Grooming unspecified backlog items before dispatch |
| `kanban-draft-adr/` | Draft an ADR from a completed ticket's evidence and outcomes | Recording architectural decisions after implementation |
| `kanban-status/` | Generate a board status report and post to ntfy | On-demand board snapshot or end-of-scrum-master-run reporting |
```

Also add to the `Key files:` line in `~/workspace/workflows/INDEX.md`:
```
kanban-adr-to-tickets/CONTEXT.md, kanban-groom-ticket/CONTEXT.md, kanban-draft-adr/CONTEXT.md, kanban-status/CONTEXT.md
```

- [ ] **Step 7.2: Verify table renders correctly**

```bash
grep "kanban" ~/workspace/workflows/INDEX.md
```
Expected: 4 lines containing `kanban-`.

- [ ] **Step 7.3: Commit workspace**

```bash
cd ~/workspace
git add workflows/kanban-adr-to-tickets/ workflows/kanban-groom-ticket/ \
        workflows/kanban-draft-adr/ workflows/kanban-status/ \
        workflows/INDEX.md
git commit -m "feat: add four kanban workflows (adr-to-tickets, groom-ticket, draft-adr, status)"
git push
```

---

## Task 8: Export to claude-code-skills and deploy

**Files:**
- Generate: `~/claude-code-skills/skills/kanban-*/SKILL.md` (all four)

- [ ] **Step 8.1: Run the full export**

```bash
~/workspace/workflows/hooks/export-skills.sh
```
Expected output:
```
Exported: kanban-adr-to-tickets → /home/lukas/claude-code-skills/skills/kanban-adr-to-tickets/SKILL.md
Exported: kanban-groom-ticket → /home/lukas/claude-code-skills/skills/kanban-groom-ticket/SKILL.md
Exported: kanban-draft-adr → /home/lukas/claude-code-skills/skills/kanban-draft-adr/SKILL.md
Exported: kanban-status → /home/lukas/claude-code-skills/skills/kanban-status/SKILL.md
Done. Exported 4 skill(s).
```

- [ ] **Step 8.2: Verify all four SKILL.md files have correct frontmatter**

```bash
for skill in kanban-adr-to-tickets kanban-groom-ticket kanban-draft-adr kanban-status; do
  echo "=== $skill ==="
  head -5 ~/claude-code-skills/skills/$skill/SKILL.md
done
```
Expected: each file starts with `---`, then `name: kanban-<slug>`, then `description:`.

- [ ] **Step 8.3: Commit and push claude-code-skills**

```bash
cd ~/claude-code-skills
git add skills/kanban-adr-to-tickets/ skills/kanban-groom-ticket/ \
        skills/kanban-draft-adr/ skills/kanban-status/
git commit -m "feat: export kanban skill suite from workspace workflows"
git push
```

- [ ] **Step 8.4: Rebuild NixOS to symlink new skills**

```bash
cd ~/nixos-config
nix flake update claude-code-skills
sudo nixos-rebuild switch --flake .#acer-swift 2>&1 | tail -5
```
Expected: no errors; switch completes.

- [ ] **Step 8.5: Verify symlinks are live**

```bash
for skill in kanban-adr-to-tickets kanban-groom-ticket kanban-draft-adr kanban-status; do
  ls -la ~/.claude/skills/$skill/SKILL.md
done
```
Expected: four symlinks pointing into the Nix store.

---

## Task 9: Scrum master — blocked_by dispatch gate

**Files:**
- Modify: `~/homelab-improvement-loop/scrum-master/GOAL.md` (Step 4 loop)

- [ ] **Step 9.1: Find the ticket dispatch loop in Step 4**

```bash
grep -n "Skip if frontmatter\|scheduled_after\|Derive session name" \
  ~/homelab-improvement-loop/scrum-master/GOAL.md | head -10
```
Note the line number of the `Skip if frontmatter` block inside the Step 4 loop.

- [ ] **Step 9.2: Add blocked_by check to the dispatch loop**

In the Step 4 dispatch loop, immediately after the `scheduled_after` skip block and before step `a. Derive session name`, insert the following block:

```markdown
   - Skip if any ticket in `blocked_by` is not yet completed:
     ```bash
     BLOCKED=0
     while IFS= read -r dep; do
       [ -z "$dep" ] || [ "$dep" = "~" ] || [ "$dep" = "[]" ] && continue
       dep=$(echo "$dep" | tr -d '[],"' | xargs)
       [ -z "$dep" ] && continue
       ls ~/knowledge-vault/Board/completed/${dep}.md 2>/dev/null || { BLOCKED=1; break; }
     done < <(grep "^blocked_by:" <ticket> | sed 's/blocked_by://' | tr ',' '\n')
     if [ "$BLOCKED" -eq 1 ]; then
       # Move to blocked/ if not already there
       echo "Skipping <ticket-id>: blocked_by dependency not yet completed"
       continue
     fi
     ```
```

- [ ] **Step 9.3: Verify the change looks right**

```bash
grep -A 15 "blocked_by" ~/homelab-improvement-loop/scrum-master/GOAL.md | head -20
```
Expected: the new `BLOCKED=0` / `blocked_by` loop appears in the file.

- [ ] **Step 9.4: Commit**

```bash
cd ~/homelab-improvement-loop
git add scrum-master/GOAL.md
git commit -m "feat: scrum master — skip dispatch for tickets with unresolved blocked_by"
```

---

## Task 10: Scrum master — Step 9 (ADR drafting) and Step 10 (status)

**Files:**
- Modify: `~/homelab-improvement-loop/scrum-master/GOAL.md` (append Steps 9-10)

- [ ] **Step 10.1: Locate the end of the scrum master GOAL.md**

```bash
tail -15 ~/homelab-improvement-loop/scrum-master/GOAL.md
```
Expected: ends with Step 8 (Print board summary).

- [ ] **Step 10.2: Append Step 9 (ADR drafting) to the end of the file**

```bash
cat >> ~/homelab-improvement-loop/scrum-master/GOAL.md << 'STEP9'

## Step 9: Draft ADRs for completed architectural tickets

For each ticket moved to `completed/` during this pass, check whether it warrants an ADR:

```bash
TYPE=$(grep "^type:" <ticket> | awk '{print $2}')
DOMAIN=$(grep "^domain:" <ticket> | awk '{print $2}')
GOAL_PREVIEW=$(grep -A 3 "^goal:" <ticket> | head -4)

NEEDS_ADR=0
echo "$TYPE $DOMAIN $GOAL_PREVIEW" | grep -qiE "rfc|platform|infra|replace|migrate|adopt|redesign|retire|upgrade" \
  && NEEDS_ADR=1
```

If `NEEDS_ADR=1`:
Read `~/workspace/workflows/kanban-draft-adr/CONTEXT.md` and follow its instructions for this ticket.

If `NEEDS_ADR=0`: skip silently.
STEP9
```

- [ ] **Step 10.3: Append Step 10 (status report) to the end of the file**

```bash
cat >> ~/homelab-improvement-loop/scrum-master/GOAL.md << 'STEP10'

## Step 10: Status report

Read `~/workspace/workflows/kanban-status/CONTEXT.md` and follow its instructions to generate `~/knowledge-vault/Board/status-latest.md` and post to ntfy.
STEP10
```

- [ ] **Step 10.4: Verify both steps were appended**

```bash
grep -n "Step 9\|Step 10\|kanban-draft-adr\|kanban-status" \
  ~/homelab-improvement-loop/scrum-master/GOAL.md | tail -10
```
Expected: 4 lines with the new step headers and skill references.

- [ ] **Step 10.5: Commit and push**

```bash
cd ~/homelab-improvement-loop
git add scrum-master/GOAL.md
git commit -m "feat: scrum master — Step 9 ADR drafting, Step 10 kanban-status report"
git push
```

---

## Task 11: Integration test — break ADR-013 into phase tickets

This task verifies the entire pipeline end-to-end using the real ADR-013 (collab-vault).

- [ ] **Step 11.1: Verify ADR-013 exists**

```bash
ls ~/workspace/homelab/decisions/ADR-013-rust-collab-knowledge-platform.md
```

- [ ] **Step 11.2: Invoke kanban-adr-to-tickets on ADR-013**

In a Claude Code session, run:

```
Use kanban-adr-to-tickets to break ~/workspace/homelab/decisions/ADR-013-rust-collab-knowledge-platform.md into Board tickets. Set epic: TICKET-2026-05-07-platform-001 on each generated ticket. Domain: platform.
```

- [ ] **Step 11.3: Verify tickets were created**

```bash
ls ~/knowledge-vault/Board/backlog/TICKET-*-platform-*.md | wc -l
```
Expected: more than 1 (the original `platform-001` plus at least 5 phase tickets).

- [ ] **Step 11.4: Verify ticket structure on the first phase ticket**

```bash
# Find the first generated phase ticket (not platform-001)
FIRST=$(ls ~/knowledge-vault/Board/backlog/TICKET-*-platform-*.md | grep -v "platform-001" | sort | head -1)
echo "=== Frontmatter check ==="
grep -E "^(id|type|epic|blocked_by|blocks|dod):" "$FIRST"
echo "=== Goal is self-contained (no 'see ADR') ==="
grep -i "see adr" "$FIRST" && echo "FAIL: contains see-adr reference" || echo "PASS: no see-adr references"
echo "=== DoD has shell commands ==="
grep "check:" "$FIRST" | head -3
```

Expected:
- `epic: TICKET-2026-05-07-platform-001`
- `blocked_by: []` on phase 1
- `blocks: [<phase-2-id>]` on phase 1
- No "see ADR" references
- At least 1 `check:` line with a shell command

- [ ] **Step 11.5: Verify dependency chain is consistent**

```bash
for f in $(ls ~/knowledge-vault/Board/backlog/TICKET-*-platform-*.md | grep -v "platform-001" | sort); do
  id=$(grep "^id:" "$f" | awk '{print $2}')
  blocks=$(grep "^blocks:" "$f")
  blocked_by=$(grep "^blocked_by:" "$f")
  echo "$id | $blocked_by | $blocks"
done
```
Expected: Phase 1 has `blocked_by: []`, each subsequent phase has `blocked_by: [<prev-id>]`.

---

## DoD verification (run after all tasks)

```bash
# Workflows exist in workspace (canonical source)
ls ~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md && echo "✓ adr-to-tickets"
ls ~/workspace/workflows/kanban-groom-ticket/CONTEXT.md && echo "✓ groom-ticket"
ls ~/workspace/workflows/kanban-draft-adr/CONTEXT.md && echo "✓ draft-adr"
ls ~/workspace/workflows/kanban-status/CONTEXT.md && echo "✓ kanban-status"

# Export script works
EXPORT_OUT=$(~/workspace/workflows/hooks/export-skills.sh 2>&1)
echo "$EXPORT_OUT" | grep -q "Done. Exported 4" && echo "✓ export script" || echo "✗ export script: $EXPORT_OUT"

# Exported and symlinked for Claude Code Skill tool
ls ~/.claude/skills/kanban-adr-to-tickets/SKILL.md && echo "✓ skill symlinked"
ls ~/.claude/skills/kanban-groom-ticket/SKILL.md && echo "✓ skill symlinked"
ls ~/.claude/skills/kanban-draft-adr/SKILL.md && echo "✓ skill symlinked"
ls ~/.claude/skills/kanban-status/SKILL.md && echo "✓ skill symlinked"

# Ticket template updated
grep -q "epic:" ~/knowledge-vault/Meta/templates/ticket.md && echo "✓ epic field"
grep -q "blocked_by:" ~/knowledge-vault/Meta/templates/ticket.md && echo "✓ blocked_by field"

# Scrum master has blocked_by dispatch gate
grep -q "blocked_by" ~/homelab-improvement-loop/scrum-master/GOAL.md && echo "✓ blocked_by gate"

# Scrum master calls kanban-draft-adr on completion
grep -q "kanban-draft-adr" ~/homelab-improvement-loop/scrum-master/GOAL.md && echo "✓ draft-adr wired"

# Scrum master calls kanban-status at end of run
grep -q "kanban-status" ~/homelab-improvement-loop/scrum-master/GOAL.md && echo "✓ kanban-status wired"

# Integration test: ADR-013 was broken into phase tickets
COUNT=$(ls ~/knowledge-vault/Board/backlog/TICKET-*-platform-*.md 2>/dev/null | grep -v "platform-001" | wc -l)
[ "$COUNT" -ge 5 ] && echo "✓ ADR-013 breakdown: ${COUNT} phase tickets" || echo "✗ Expected ≥5 phase tickets, got ${COUNT}"
```
