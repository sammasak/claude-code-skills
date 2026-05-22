---
name: kanban-status
description: >-
  Generate a board status report from the current kanban board state. Writes to ~/knowledge-vault/Board/status-latest.md, commits, and posts a summary to ntfy.
---

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

For completed-today: `git -C ~/workspace log --since="24 hours ago" --name-only --diff-filter=AR --pretty="" -- Board/completed/ | grep "\.md$"`

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
<For each waiting ticket, sorted critical->low:>
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
git -C ~/workspace add Board/status-latest.md
git -C ~/workspace commit -m "board: status update $(date -Iseconds)" || true
git -C ~/workspace push

# Post first 20 lines to ntfy
curl -s \
  -H "Title: Board Status $(date +%Y-%m-%d\ %H:%M)" \
  -H "Tags: clipboard" \
  -d "$(head -20 ~/knowledge-vault/Board/status-latest.md)" \
  http://10.43.19.253/homelab-improvements || true
```
