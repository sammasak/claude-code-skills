---
name: orchestrated-review
description: >
  Use when reviewing any implementation. Replaces fixed spec+quality two-step with
  category-driven parallel specialists: an assessor picks relevant categories for the
  specific artifact, one specialist per category reviews in parallel, controller aggregates.
  Use after implementer completes a task in subagent-driven-development.
---

# Orchestrated Code Review

Replace the fixed spec+quality two-step with emergent categories. An assessor reads the
files and selects the 3–5 most relevant categories from the catalog. One specialist per
category reviews in parallel. The controller aggregates and decides.

**Prerequisites:** verify these files exist before starting:
- `~/workspace/workflows/recursive-review/prompts/assessor.md`
- `~/workspace/workflows/recursive-review/prompts/reviewer.md`
- `~/workspace/workflows/recursive-review/categories.yaml`

If any are missing, abort and tell the user.

**`categories.yaml` structure** — three top-level keys (`code:`, `docs:`, `configs:`), each containing named categories with `description`, `default_weight`, and `applicable_to` glob list. The assessor selects applicable categories per chunk and re-normalizes weights. Pass the full file contents verbatim as `{{CATEGORIES_YAML}}`.

**Template contracts:**
- `assessor.md` accepts: `{{FILES}}` (file list), `{{CATEGORIES_YAML}}` (full yaml). Returns JSON with `chunks[]` — see expected shape below.
- `reviewer.md` accepts: `{{CHUNK_FILES}}`, `{{CATEGORY}}`, `{{CATEGORY_DESCRIPTION}}`, `{{ITERATION}}`. Returns JSON with `category`, `score`, `summary`, `findings[]`.

## Stage 1 — Assess

**Dispatch one assessor subagent** using the Task tool with `subagent_type=general-purpose`.
Use the prompt template at `~/workspace/workflows/recursive-review/prompts/assessor.md`,
replacing:

- `{{FILES}}` — the changed file paths for this task (one per line)
- `{{CATEGORIES_YAML}}` — full contents of `~/workspace/workflows/recursive-review/categories.yaml`

**If reviewing against a task spec:** add a `## Task Spec` heading at the end of the
rendered assessor prompt and paste the full spec text under it. Also instruct the assessor
to add a custom category:
```
Custom category: spec-compliance
Description: Does the implementation match the task spec exactly? Nothing missing, nothing extra.
Weight: 0.25 (drawn from the re-normalized pool)
```

**Expected assessor output shape:**
```json
{"chunks": [{"id": "...", "description": "...", "files": [{"path": "...", "lines": 0, "artifact_type": "..."}], "categories": [{"name": "...", "description": "...", "weight": 0.0, "source": "catalog|proposed"}]}]}
```
(controller uses: `chunks[].files[].path` and `chunks[].categories[].name`/`description` — full schema in `assessor.md`)

A chunk is a logical grouping of related files the assessor clusters — treat each as an
opaque list of file paths.

**Edge case:** if the assessor returns `chunks: []`, abort and tell the user: "Assessor found no reviewable files."

**Gate:** do not dispatch any Stage 2 Task calls until the assessor subagent returns its full JSON output, and dispatch them in a **separate response turn** — never in the same message as the assessor Task call.

## Stage 2 — Review (parallel)

**Dispatch all specialist reviewers in a single message.** For each chunk in `chunks[]`,
dispatch one Task call per category in that chunk's `categories[]` — all Task calls for
ALL chunks go in the same single message.

Use the Task tool with `subagent_type=general-purpose` and the reviewer prompt at
`~/workspace/workflows/recursive-review/prompts/reviewer.md`, replacing:

- `{{CHUNK_FILES}}` — file paths in this chunk
- `{{CATEGORY}}` — category name
- `{{CATEGORY_DESCRIPTION}}` — category description from assessor output
- `{{ITERATION}}` — always `1` in this skill — the reviewer uses it to adjust focus (iteration 1 = fresh review; higher values would focus on previously flagged issues), but this skill always passes 1; prior run context is conveyed via `## Prior Findings` instead

Each reviewer returns JSON:
```json
{"category": "...", "score": 0-100, "summary": "...", "findings": [
  {"file": "...", "line": 0, "severity": "critical|major|minor", "description": "...", "suggestion": "..."}
]}
```

## Stage 3 — Aggregate (controller, no subagent)

Collect all reviewer JSON outputs and produce a consolidated report.

If a reviewer returns malformed output or fails, record that category as `score=0` with a
single critical finding: `"Reviewer failed — category not assessed."`

**Decision (no numeric overall score is computed — the decision is determined solely by
finding disposition):**
- Any `critical` finding → **NOT APPROVED** — implementer must fix all critical findings
  before proceeding
- No `critical`, any `major` finding → **APPROVED WITH FIXES** — implementer should fix
  major findings
- No `critical` or `major` findings → **APPROVED**

**Output format:**
```
## Review Result: [NOT APPROVED | APPROVED WITH FIXES | APPROVED]

### Scores
| Chunk | Category | Score |
|-------|----------|-------|

### Findings
| File | Line | Severity | Category | Description | Suggestion |
|------|------|----------|----------|-------------|------------|
```

## Re-run Semantics

After a NOT APPROVED decision:
1. Always restart at **Stage 1** — the assessor re-runs; categories from the prior run are not reused
2. Dispatch Stage 2 reviewers as normal
3. Append a `## Prior Findings` section to each reviewer prompt containing all `critical` and `major` findings from the prior run, grouped by file — this helps reviewers confirm fixes

`{{ITERATION}}` always stays `1` on re-runs — prior run context is conveyed exclusively via `## Prior Findings`, not via the iteration counter.

## When to use

- Use in place of both spec compliance and code quality review steps
- The `spec-compliance` custom category covers spec checking
- Run once per task after the implementer commits
- If NOT APPROVED: implementer fixes, then re-run this skill (see Re-run Semantics above).

## Red flags

- Never dispatch reviewers before the assessor returns (categories must be known)
- Never dispatch reviewers sequentially — all must run in parallel (single message)
- Never skip aggregation — all reviewer outputs must be collected before determining the decision, even if some categories score low
- Never combine assessor and reviewer Task calls in the same message — Stage 2 must be dispatched in a **separate response turn** after the assessor result is received
