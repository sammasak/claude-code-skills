---
name: kanban-groom-ticket
description: >-
  Take a vague or under-specified Board backlog ticket and flesh it out into a fully actionable specification with concrete implementation steps and executable DoD checks.
---

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
  lines=$(awk '/^goal:/,/^dod:/' "$f" | grep -v "^goal:" | grep -v "^dod:" | wc -l)
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
