---
name: kanban-groom-ticket
description: >-
  Take a vague or under-specified Board backlog ticket and flesh it out into a fully actionable specification with concrete implementation steps and executable DoD checks.
---

Take a vague or under-specified Board backlog ticket and flesh it out into a fully actionable specification with concrete implementation steps and executable DoD checks.

## When to use

When a ticket in `~/workspace/Board/backlog/` has any of:
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
for f in ~/workspace/Board/backlog/*.md; do
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
   - `docs`: read the relevant section in `~/workspace/knowledge/` or `~/workspace/homelab/`
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
git -C ~/workspace add Board/backlog/<ticket-filename>
git -C ~/workspace commit -m "board: groom ${TICKET_ID} — add goal and DoD"
git -C ~/workspace push
```

## DoD Authoring Rules

Roughly half of failed tickets fail because the DoD command was authored
badly, not because the implementation was wrong (e.g. e2e-011 regex
didn't match Playwright `--reporter=list` success output; rust-001 ran
a bare `cargo test` that hit pre-existing baseline failures unrelated
to the ticket). Apply these rules to every `check:` you author or
review during grooming.

### 1. Match the success line, not its absence

`pytest -q`, `cargo test`, and Playwright's `--reporter=list` omit the
failure count when nothing fails. Regexes that try to find `failed.*0`
will never match a clean run.

**Bad:**
```bash
grep -qE 'passed.*failed.*0|passed \(1[.]'   # depends on duration formatting
```

**Good — assert success token AND absence of any failure count:**
```bash
echo "$OUT" | grep -qE '\b[0-9]+ passed\b' && ! echo "$OUT" | grep -qE '\b[1-9][0-9]* failed\b'
```

For tools with reliable exit codes, prefer the exit code over parsing output:
```bash
playwright test 03-forward-auth.spec.js --reporter=list   # exit 0 ⇔ all passed
```

### 2. Scope tests narrowly

A bare `cargo test` runs the full crate including stale integration
suites. A bare `pytest` runs the full repo. Either can fail on
pre-existing baseline failures unrelated to the ticket and sink an
otherwise clean implementation (rust-001 hit this).

**Bad:**
```bash
cd ~/workstation-api && cargo test
pytest
```

**Good — narrow to what changed:**
```bash
cd ~/workstation-api && cargo test --lib                    # library unit tests only
cd ~/workstation-api && cargo test --test smoke             # named integration suite
pytest tests/test_handlers.py::test_create_workspace        # single test
```

If the ticket genuinely requires the full suite to pass, verify the
baseline is clean before grooming and say so explicitly in the DoD
`description:`.

### 3. Cluster-state checks belong post-merge

Flux reconciles for HelmReleases and cross-Kustomization namespace
creation take 15–25 minutes. A `kubectl get … -o jsonpath` check that
runs in the worker before the impl PR merges will fail. Author the
check so it runs in the Step 3b verifying lane — the 30-minute grace
window is designed for this latency (see devex-005). The check itself
stays the same; only the phase it runs in differs.

### 4. No unbounded greps on long-lived files

`grep -q 'foo' large.log` will pass on any historical mention of `foo`
— including the bug the ticket is trying to fix. Bound the grep to
recent content with `tail -N` or a timestamp filter.

**Bad:**
```bash
grep -q 'reconciled successfully' /var/log/flux.log
```

**Good:**
```bash
tail -200 /var/log/flux.log | grep -q 'reconciled successfully'
journalctl --since '5 min ago' -u flux | grep -q 'reconciled successfully'
```

### Authoring checklist

Apply to every new `check:` before committing the groomed ticket:
- [ ] Does the assertion match the actual successful output of the tool (not its absence)?
- [ ] Is test scope narrowed to what this ticket changes (`--lib`, `--test <suite>`, single test name)?
- [ ] If it reads cluster state, is it phrased so it runs post-merge in Step 3b?
- [ ] If it greps a log, is it bounded by `tail -N` or a timestamp filter?
