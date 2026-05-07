# Kanban Skill Suite — Design

**Date:** 2026-05-07
**Status:** Approved
**Sub-project:** 1 of 5 in the full LLM-driven kanban flow

## Problem

The homelab multi-agent loop covers: detect signals → create tickets → dispatch workers → review PRs → verify DoD. What engineers do that the loop does NOT:

- Break large ADRs/epics into per-phase tickets (collab-vault ADR-013 sits as one unsplittable blob)
- Groom vague backlog items into actionable specifications
- Draft ADRs from the outcomes of completed tickets
- Generate a standup/status view of the board

These are the four missing building blocks. Everything else in the full kanban vision (groomer agent, epic rollup, retro writer, doc updater) composes on top of them.

## Architecture

### Canonical home: `~/workspace/workflows/`

Workflows live primarily in the ICM workspace (the knowledge vault), one directory per
workflow with a plain `CONTEXT.md` as the operational payload. This is the same convention
used by all existing workflows (tdd, diagnose, to-issues, etc.) and established by
ADR-001-mattpocock-skills-as-workflows.

```
~/workspace/workflows/
  kanban-adr-to-tickets/CONTEXT.md   ← decompose ADR phases into Board tickets
  kanban-groom-ticket/CONTEXT.md     ← flesh out vague tickets into actionable specs
  kanban-draft-adr/CONTEXT.md        ← draft ADR from completed ticket outcomes
  kanban-status/CONTEXT.md           ← generate standup / board status report
```

### Export layer: `~/claude-code-skills/skills/`

The claude-code-skills repo is a derived artifact. An export script wraps each
`workflows/*/CONTEXT.md` in a thin SKILL.md frontmatter envelope so Claude Code can
discover and invoke it via the Skill tool. The export runs via `just export-skills` in
the workspace Justfile.

```
~/claude-code-skills/skills/
  kanban-adr-to-tickets/SKILL.md   ← generated: frontmatter + CONTEXT.md content
  kanban-groom-ticket/SKILL.md     ← generated
  kanban-draft-adr/SKILL.md        ← generated
  kanban-status/SKILL.md           ← generated
```

**Export script** (`~/workspace/workflows/hooks/export-skills.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail
WORKFLOWS="$HOME/workspace/workflows"
SKILLS="$HOME/claude-code-skills/skills"

for dir in "$WORKFLOWS"/*/; do
  name=$(basename "$dir")
  ctx="$dir/CONTEXT.md"
  [ -f "$ctx" ] || continue
  # Only export workflows that opt in via frontmatter export: true
  grep -q "^export: true" "$ctx" || continue
  description=$(grep -m1 "^[^#\-]" "$ctx" | head -1 | sed 's/^[[:space:]]*//')
  mkdir -p "$SKILLS/$name"
  printf -- "---\nname: %s\ndescription: >-\n  %s\n---\n\n" "$name" "$description" \
    > "$SKILLS/$name/SKILL.md"
  grep -v "^export: true" "$ctx" >> "$SKILLS/$name/SKILL.md"
done
```

Workflows opt in by including `export: true` in their CONTEXT.md frontmatter. Existing
mattpocock-derived workflows without frontmatter are unaffected.

### Dual-mode invocation

Each workflow/skill is reachable in two ways:
1. **Interactive** — Skill tool invokes `kanban-adr-to-tickets` in a Claude Code session
2. **Headless agent** — GOAL.md reads `~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md`
   with the Read tool and follows its instructions directly from the workspace canonical copy

### Ticket schema extensions

The live Board ticket schema (from the multi-agent kanban ADR) is missing fields that the skills need. Add to ticket frontmatter:

```yaml
# Epic / dependency tracking
epic: ~                  # ID of the parent epic ticket, e.g. TICKET-2026-05-07-platform-001
parent_ticket: ~         # Direct parent ticket ID (for sub-tasks within an epic)
blocks: []               # Ticket IDs that cannot start until this one completes
blocked_by: []           # Ticket IDs that must complete before this one can start

# Planning metadata
estimated_effort: ~      # e.g. "2-4 hours", "1 day", "1 week"
labels: []               # e.g. [rust, k8s, auth, breaking-change]
```

These fields are optional (default `~` / `[]`). Existing tickets remain valid without them. The scrum master uses `blocked_by` to skip dispatch of blocked tickets; `epic` lets the status skill group tickets by initiative.

Update `~/knowledge-vault/Meta/templates/ticket.md` to include these fields.

### Scrum master integration

Add two new phases to `~/homelab-improvement-loop/scrum-master/GOAL.md`:

**Phase 6 (after DoD verified, before move to completed):**
If ticket `type: rfc` OR `domain: infra|platform|architecture` OR goal contains "replace"/"migrate"/"adopt"/"redesign": read `~/claude-code-skills/skills/kanban-draft-adr/SKILL.md` and follow its instructions for the ticket.

**Phase 7 (end of each run):**
Read `~/claude-code-skills/skills/kanban-status/SKILL.md` and follow its instructions to update `Board/status-latest.md` and post to ntfy.

---

## Skill 1: `kanban-adr-to-tickets`

### Trigger
Use when an ADR has a `## Implementation Plan` section with multiple phases/steps and needs to be broken into individual Board tickets.

### Inputs
- ADR file path (required)
- Target domain (optional, inferred from ADR content if absent)
- Priority override (optional, defaults to `medium`)

### Process

**Step 1 — Parse the ADR**
Read the full ADR. Locate `## Implementation Plan`. Extract all Phase sections (identified by `### Phase N` or numbered sections). For each phase, capture:
- Phase title and description
- Numbered steps
- DoD checks (the `yaml` block under each phase, or inline shell command lines)

**Step 2 — Check for existing tickets (idempotency)**
```bash
grep -r "epic: TICKET-<source-ticket-id>" ~/knowledge-vault/Board/ --include="*.md" -l 2>/dev/null
```
If tickets already exist for this ADR's phases, report them and exit. Do not create duplicates.

**Step 3 — Generate ticket IDs**
Determine the next available ticket number for the target domain and today's date:
```bash
ls ~/knowledge-vault/Board/backlog/ | grep "TICKET-$(date +%Y-%m-%d)-<domain>" | wc -l
```
Assign IDs sequentially: `TICKET-YYYY-MM-DD-<domain>-NNN`.

**Step 4 — Write ticket files**

For each phase, write `~/knowledge-vault/Board/backlog/TICKET-YYYY-MM-DD-<domain>-NNN.md` with:

```yaml
---
id: TICKET-YYYY-MM-DD-<domain>-NNN
type: task
title: "<ADR title> — Phase N: <phase title>"
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

epic: <source-ticket-id>        # e.g. TICKET-2026-05-07-platform-001
parent_ticket: ~
blocks: [<next-phase-ticket-id>]
blocked_by: [<prev-phase-ticket-id>]

estimated_effort: ~
labels: []

goal: |
  ## Context
  This ticket implements Phase N of <ADR title>.
  Full ADR: <ADR file path>

  ## Background
  <2-3 sentences from ADR context section explaining WHY this phase exists>

  ## Steps
  <All numbered steps from the ADR phase, fully inlined. No references to "see ADR".
  Include all bash commands verbatim. A worker must be able to complete this ticket
  without reading the ADR.>

  ## Exit protocol
  After completing all steps, run each DoD check below.
  If ALL pass: write 0 to $WORKER_EXIT_FILE.
  If ANY fail: write 1 to $WORKER_EXIT_FILE and append ## DoD Failures listing
  which checks failed and their output.

dod:
  # Each check inlined from the ADR's phase DoD section.
  # Every check MUST be a shell command that exits 0 on success.
  - check: "<shell command>"
    description: "<what this verifies>"

evidence: |
  Generated by kanban-adr-to-tickets skill from <ADR file path> on YYYY-MM-DD.
  Source phase: Phase N — <phase title>
---
```

**Step 5 — Set dependency chain**
Phase 1: `blocked_by: []`, `blocks: [TICKET-...-NNN+1]`
Phase N (middle): `blocked_by: [TICKET-...-NNN-1]`, `blocks: [TICKET-...-NNN+1]`
Phase last: `blocked_by: [TICKET-...-NNN-1]`, `blocks: []`

**Step 6 — Commit and open PR**
```bash
cd ~/knowledge-vault
git checkout -b ticket/adr-<slug>-breakdown
git add Board/backlog/TICKET-*.md
git commit -m "board: break <ADR title> into <N> phase tickets"
git push -u origin ticket/adr-<slug>-breakdown
gh pr create --repo sammasak/knowledge-vault \
  --title "ticket: <ADR title> phase breakdown" \
  --body "Breaks <ADR path> into N phase tickets for the kanban board. Generated by kanban-adr-to-tickets."
```

### Constraints
- Every `goal:` field must be self-contained. No "see ADR" references. Inline everything.
- Every `dod:` item must be an executable shell command. No prose-only checks.
- Phase tickets are created in dependency order, each `blocked_by` the previous phase's ticket.
- The scrum master respects `blocked_by`: a ticket is not dispatched until all tickets in its `blocked_by` list are in `completed`.

---

## Skill 2: `kanban-groom-ticket`

### Trigger
Use when a Board backlog ticket has a vague or incomplete specification — no executable DoD, goal under 5 lines, or missing `type`/`priority`.

A ticket is **ungroomed** if ANY of:
- `goal:` is fewer than 8 lines
- `dod:` is empty or has no shell commands (`check:` entries are all prose)
- `type:` is `~`
- `priority:` is `~`

A ticket is **groomed** when ALL of:
- `goal:` has numbered steps with at least one concrete bash command
- `dod:` has at least 2 items with shell commands that exit 0 on success
- `type:` and `priority:` are set

### Process

**Step 1 — Identify ungroomed tickets**
```bash
for f in ~/knowledge-vault/Board/backlog/*.md; do
  lines=$(grep -A 200 "^goal:" "$f" | grep -v "^dod:" | wc -l)
  dod_checks=$(grep "check:" "$f" | wc -l)
  [ "$lines" -lt 8 ] || [ "$dod_checks" -lt 2 ] && echo "$f"
done
```

**Step 2 — Research context**
For each ungroomed ticket:
- Read `evidence:` to understand why it was created
- Read relevant docs: if domain is `infra`, check cluster state; if domain is `apps`, read relevant deployment manifests; if domain is `skills`, read existing skill files
- Identify what success looks like (what must be true when the ticket is done?)

**Step 3 — Write the groomed ticket**

Rewrite `goal:` as a numbered, self-contained implementation guide:
```
## Context
<2-3 sentences why this matters>

## Steps
1. <concrete step with bash command>
2. <concrete step>
...

## Verification
Run the DoD checks below before marking done.
```

Write `dod:` with concrete shell checks. If a DoD item cannot be expressed as a shell command (e.g., "human should verify the UI looks correct"), express it as:
```yaml
- check: "echo 'HUMAN GATE: verify X manually then run: touch /tmp/verified-X'"
  description: "Human verification gate for X"
```

Set `type:` (task / rfc / chore / incident) and `priority:` (critical / high / medium / low) and `estimated_effort:`.

**Step 4 — Commit**
```bash
git -C ~/knowledge-vault add Board/backlog/<filename>
git -C ~/knowledge-vault commit -m "board: groom TICKET-<id> — add goal and DoD"
git -C ~/knowledge-vault push
```

---

## Skill 3: `kanban-draft-adr`

### Trigger
Use when a ticket is being moved to `completed` and the work involved an architectural decision. Indicators:
- `type: rfc`
- `domain: infra`, `platform`, or `architecture`
- `goal:` contains any of: replace, migrate, adopt, reject, redesign, retire

### Inputs
- Ticket file path (required)
- PR URL (optional — read diff if provided)

### Process

**Step 1 — Determine ADR location and number**
Map ticket `domain:` to project decisions directory:
- `infra`, `platform`: `~/workspace/homelab/decisions/`
- `apps`: `~/workspace/dev/<app>/decisions/` (infer app from ticket title)
- `skills`: `~/workspace/claude-code-skills/decisions/`

Find the next ADR number:
```bash
ls <decisions-dir> | grep "^ADR-" | sort -V | tail -1 | grep -oP 'ADR-\K\d+' | awk '{printf "%03d", $1+1}'
```

**Step 2 — Read evidence**
From the ticket: `title`, `goal`, `dod`, `evidence`, `impl_pr_url`.
If PR URL exists: `gh pr view <url> --json title,body,files` to get changed files and description.

**Step 3 — Draft the ADR**

Write `ADR-NNN-<slug>.md` using the standard format:

```markdown
---
status: accepted
date: YYYY-MM-DD
supersedes: null
related:
  - <ticket id>
  - <any related ADRs found in ticket or PR>
---

# ADR-NNN: <title from ticket>

## Context
<Why this decision was needed. Draw from ticket evidence: + cluster state + signals the monitor found.>

## Decision
<One sentence. What was done.>

## Options Considered
| Option | Description | Verdict |
|---|---|---|
| **A. <chosen>** | <what was done> | **Chosen** |
| **B. Status quo** | <what would have happened without action> | Rejected |
<Add more options if the ticket goal mentions alternatives.>

## Consequences
**Benefits:** <what the DoD checks now guarantee — one bullet per DoD item>
**Trade-offs:** <any negatives, caveats, or follow-on work>

## Links
- Ticket: <ticket id>
- PR: <impl_pr_url if set>
```

**Step 4 — Commit**
```bash
git -C ~/workspace add <decisions-dir>/ADR-NNN-<slug>.md
git -C ~/workspace commit -m "docs: ADR-NNN — <title>"
git -C ~/workspace push
```

---

## Skill 4: `kanban-status`

### Trigger
Use on demand for a board status report, or as part of the scrum master's end-of-run phase.

### Process

**Step 1 — Read board state**
```bash
for col in backlog waiting in-progress review verifying needs-info on-hold blocked failed completed; do
  count=$(ls ~/knowledge-vault/Board/$col/ 2>/dev/null | grep -v '.gitkeep' | wc -l)
  echo "$col: $count"
done
```

For in-progress tickets: read `assigned_worker`, `worker_started`, `title`.
For blocked/needs-info: read `title` and first line of `evidence`.
For recently completed (last 24h): `git -C ~/knowledge-vault log --since="24 hours ago" --name-only --pretty="" -- Board/completed/`.

**Step 2 — Generate report**

Write to `~/knowledge-vault/Board/status-latest.md`:

```markdown
# Board Status — YYYY-MM-DD HH:MM

## In Progress (<n>/<max_concurrent> capacity)
- **TICKET-id** — <title> (worker: <assigned_worker>, <elapsed> elapsed)
...

## Queued (waiting: <n>)
- **TICKET-id** [<priority>] — <title>
...

## Needs Info (<n>)
- **TICKET-id** — <title> — <first line of evidence>
...

## Completed Today (<n>)
- ✓ TICKET-id — <title>
...

## Failed (<n>)
- ✗ TICKET-id — <title>
...

## Backlog (<n> tickets, <n> ungroomed)
```

**Step 3 — Commit and notify**
```bash
git -C ~/knowledge-vault add Board/status-latest.md
git -C ~/knowledge-vault commit -m "board: status update $(date -Iseconds)"
git -C ~/knowledge-vault push

curl -s -d "$(cat ~/knowledge-vault/Board/status-latest.md | head -30)" \
  http://10.43.19.253/homelab-improvements
```

---

## Scrum master changes

Add to the end of `~/homelab-improvement-loop/scrum-master/GOAL.md`:

**Phase 6 — ADR drafting (after DoD verified)**
After moving a ticket to `completed` (not `review`), check if the ticket warrants an ADR:
```bash
TYPE=$(grep '^type:' <ticket> | awk '{print $2}')
DOMAIN=$(grep '^domain:' <ticket> | awk '{print $2}')
GOAL=$(grep -A 5 '^goal:' <ticket>)

if echo "$TYPE $DOMAIN $GOAL" | grep -qiE 'rfc|platform|infra|replace|migrate|adopt|redesign|retire'; then
  # Read ~/claude-code-skills/skills/kanban-draft-adr/SKILL.md and follow its instructions
  # for this ticket.
fi
```

**Phase 7 — Status report (end of every run)**
Read `~/claude-code-skills/skills/kanban-status/SKILL.md` and follow its instructions.

**Dispatch gate for `blocked_by`:**
In Phase 3 (assign workers), skip any waiting ticket where `blocked_by:` contains a ticket
NOT in `Board/completed/`:
```bash
for dep in $(grep '^blocked_by:' <ticket> | yq -r '.blocked_by[]' 2>/dev/null); do
  ls ~/knowledge-vault/Board/completed/${dep}.md 2>/dev/null || { echo "blocked"; break; }
done
```

---

## Deployment

**Step 1 — Commit workflows to workspace:**
```bash
cd ~/workspace && git add workflows/kanban-*/ && git commit -m "feat: kanban skill suite workflows" && git push
```

**Step 2 — Export to claude-code-skills:**
```bash
cd ~/workspace && bash workflows/hooks/export-skills.sh
cd ~/claude-code-skills && git add skills/kanban-*/ && git commit -m "feat: export kanban skills from workspace" && git push
```

**Step 3 — Rebuild NixOS to symlink new skills:**
```bash
cd ~/nixos-config && nix flake update claude-code-skills
sudo nixos-rebuild switch --flake .#acer-swift
```

The scrum master reads workflows directly from `~/workspace/workflows/*/CONTEXT.md` (the canonical copy), so no NixOS rebuild is needed for agent use. Only the interactive Skill tool invocation needs the rebuild.

---

## Definition of Done

All four skills are complete when:

```bash
# Workflows exist in workspace (canonical source)
ls ~/workspace/workflows/kanban-adr-to-tickets/CONTEXT.md
ls ~/workspace/workflows/kanban-groom-ticket/CONTEXT.md
ls ~/workspace/workflows/kanban-draft-adr/CONTEXT.md
ls ~/workspace/workflows/kanban-status/CONTEXT.md

# Exported and symlinked for Claude Code Skill tool
ls ~/.claude/skills/kanban-adr-to-tickets/SKILL.md
ls ~/.claude/skills/kanban-groom-ticket/SKILL.md
ls ~/.claude/skills/kanban-draft-adr/SKILL.md
ls ~/.claude/skills/kanban-status/SKILL.md

# Ticket template updated
grep -q 'epic:' ~/knowledge-vault/Meta/templates/ticket.md
grep -q 'blocked_by:' ~/knowledge-vault/Meta/templates/ticket.md

# Scrum master has blocked_by dispatch gate
grep -q 'blocked_by' ~/homelab-improvement-loop/scrum-master/GOAL.md

# Scrum master calls kanban-draft-adr on completion
grep -q 'kanban-draft-adr' ~/homelab-improvement-loop/scrum-master/GOAL.md

# Scrum master calls kanban-status at end of run
grep -q 'kanban-status' ~/homelab-improvement-loop/scrum-master/GOAL.md

# Integration test: adr-to-tickets produces valid tickets for ADR-013
ls ~/knowledge-vault/Board/backlog/TICKET-*-platform-*.md | wc -l | grep -qv '^1$'
# (more than 1 platform ticket = ADR-013 was broken into phases)
```

---

## What comes next (Sub-projects 2-5)

Sub-project 2 adds a **groomer agent** (weekly systemd timer) that runs `kanban-groom-ticket` across the full backlog automatically.

Sub-project 3 adds **epic management**: `Board/epics/` directory, scrum master epic-rollup phase, progress percentage on parent tickets.

Sub-project 4 extends the **completion loop**: doc-updater phase (update knowledge-vault docs when ticket completes), retro-writer phase (auto-generate post-mortem for failed tickets).

Sub-project 5 adds **status reporting** as a standalone daily agent posting to ntfy.
