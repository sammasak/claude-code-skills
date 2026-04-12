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
{"chunks": [{"id": "...", "files": [...], "categories": [{"name": "...", "description": "..."}]}]}
```

A chunk is a logical grouping of related files the assessor clusters — treat each as an
opaque list of file paths.

**Gate: do not proceed to Stage 2 until the assessor returns its full JSON. Stage 2 must
be dispatched in a separate response.**

## Stage 2 — Review (parallel)

**Dispatch all specialist reviewers in a single message.** For each chunk in `chunks[]`,
dispatch one Task call per category in that chunk's `categories[]` — all Task calls for
ALL chunks go in the same single message.

Use the Task tool with `subagent_type=general-purpose` and the reviewer prompt at
`~/workspace/workflows/recursive-review/prompts/reviewer.md`, replacing:

- `{{CHUNK_FILES}}` — file paths in this chunk
- `{{CATEGORY}}` — category name
- `{{CATEGORY_DESCRIPTION}}` — category description from assessor output
- `{{ITERATION}}` — always `1` (reserved for multi-pass workflows; always pass 1 here)

**On re-run (after a NOT APPROVED decision):** always start fresh from Stage 1 (assessor
re-runs; categories are not reused from the prior run). Pass prior findings as additional
context to each reviewer by appending a `## Prior Findings` section to the rendered
reviewer prompt.

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

## When to use

- Use in place of both spec compliance and code quality review steps
- The `spec-compliance` custom category covers spec checking
- Run once per task after the implementer commits
- If NOT APPROVED: implementer fixes, then re-run this full skill (Stage 1 always re-runs;
  categories are not reused from the prior run)

## Red flags

- Never dispatch reviewers before the assessor returns (categories must be known)
- Never dispatch reviewers sequentially — all must run in parallel (single message)
- Never skip aggregation — a low score in any category means findings to report
