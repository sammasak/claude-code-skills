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

## Stage 1 — Assess

**Dispatch one assessor subagent.** Use the prompt template at
`~/workspace/workflows/recursive-review/prompts/assessor.md`, replacing:

- `{{FILES}}` — the changed file paths for this task (one per line)
- `{{CATEGORIES_YAML}}` — full contents of `~/workspace/workflows/recursive-review/categories.yaml`

The assessor returns JSON with `chunks[]`, each chunk having `categories[]` selected for
those files. It may also propose custom categories.

**If reviewing against a task spec:** instruct the assessor to add a custom category:
```
Custom category: spec-compliance
Description: Does the implementation match the task spec exactly? Nothing missing, nothing extra.
Weight: 0.25 (drawn from the re-normalized pool)
```
Pass the task spec text to the assessor as additional context.

## Stage 2 — Review (parallel)

**Dispatch all specialist reviewers in a single message** (one Task tool call per
(chunk, category) pair — all in the same response). Use the reviewer prompt at
`~/workspace/workflows/recursive-review/prompts/reviewer.md`, replacing:

- `{{CHUNK_FILES}}` — file paths in this chunk
- `{{CATEGORY}}` — category name
- `{{CATEGORY_DESCRIPTION}}` — category description from assessor output
- `{{ITERATION}}` — always `1`

Each reviewer returns JSON:
```json
{"category": "...", "score": 0-100, "summary": "...", "findings": [
  {"file": "...", "line": 0, "severity": "critical|major|minor", "description": "...", "suggestion": "..."}
]}
```

## Stage 3 — Aggregate (controller, no subagent)

Collect all reviewer JSON outputs and produce a consolidated report:

| Severity | Disposition |
|----------|-------------|
| `critical` | NOT APPROVED — implementer must fix all before proceeding |
| `major` | APPROVED WITH FIXES — implementer should fix |
| `minor` | NOTE — optional improvement, not blocking |

**Decision:**
- Any `critical` → **NOT APPROVED**
- No `critical`, any `major` → **APPROVED WITH FIXES**
- All clean → **APPROVED**

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
- If NOT APPROVED: implementer fixes, then re-run this full skill

## Red flags

- Never dispatch reviewers before the assessor returns (categories must be known)
- Never dispatch reviewers sequentially — all must run in parallel (single message)
- Never skip aggregation — a low score in any category means findings to report
