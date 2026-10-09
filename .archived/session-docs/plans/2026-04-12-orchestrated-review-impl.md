# Orchestrated Review Skill — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an `orchestrated-review` skill that replaces the fixed spec+quality two-step review in subagent-driven-development with a category-driven parallel review: an assessor picks the right categories for the specific artifact, then one specialist per category reviews in parallel.

**Architecture:** Three stages, all in the controller session (no external process). Stage 1: assessor subagent reads the files and selects categories from `~/workspace/workflows/recursive-review/categories.yaml`, plus can propose custom ones (including spec compliance). Stage 2: one specialist reviewer subagent per (chunk, category) pair, all dispatched in a single message. Stage 3: controller aggregates scores — any critical finding blocks, majors get fixed by implementer, minors are noted.

**Tech Stack:** Markdown skill file, references existing `recursive-review` prompt templates and `categories.yaml` in `~/workspace`.

---

### Task 1: Create orchestrated-review skill

**Files:**
- Create: `~/claude-code-skills/skills/orchestrated-review/SKILL.md`

**Step 1: Create the directory**

```bash
mkdir -p ~/claude-code-skills/skills/orchestrated-review
```

**Step 2: Write the skill file**

Write `~/claude-code-skills/skills/orchestrated-review/SKILL.md`:

````markdown
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

**Dispatch one assessor subagent.** Provide the full text of the assessor prompt below,
with `{{FILES}}` and `{{CATEGORIES_YAML}}` replaced.

- `{{FILES}}` — the changed file paths for this task (list each on its own line)
- `{{CATEGORIES_YAML}}` — full contents of `~/workspace/workflows/recursive-review/categories.yaml`

The assessor returns JSON with `chunks[]`, each chunk with `categories[]` selected for
those files. It may also propose custom categories — including `spec-compliance` if a task
spec was provided.

**If reviewing against a task spec:** tell the assessor to add a custom category:
```
Proposed custom category: spec-compliance
Description: Does the implementation match the task spec exactly? Nothing missing, nothing extra.
Weight: 0.25 (draw from the re-normalized pool)
```

**Assessor prompt template:** `~/workspace/workflows/recursive-review/prompts/assessor.md`

## Stage 2 — Review (parallel)

**Dispatch all specialist reviewers in a single message** (one Task tool call per
(chunk, category) pair). Use the reviewer prompt template for each:

- `{{CHUNK_FILES}}` — the file paths in this chunk
- `{{CATEGORY}}` — the category name
- `{{CATEGORY_DESCRIPTION}}` — the category description from the assessor output
- `{{ITERATION}}` — always `1` (no convergence loop here)

**Reviewer prompt template:** `~/workspace/workflows/recursive-review/prompts/reviewer.md`

Each reviewer returns JSON: `{"category": "...", "score": 0-100, "summary": "...", "findings": [...]}`.

## Stage 3 — Aggregate (controller, no subagent)

Collect all reviewer JSON outputs. For each finding:

| Severity | Action |
|----------|--------|
| `critical` | NOT APPROVED — implementer must fix all critical findings |
| `major` | APPROVED WITH FIXES — implementer should fix before merge |
| `minor` | NOTE — optional improvement, not blocking |

**Decision:**
- Any `critical` finding → **NOT APPROVED**. List all findings grouped by file.
- No `critical`, any `major` → **APPROVED WITH FIXES**. List majors.
- All clean → **APPROVED**.

**Output format:**

```
## Review Result: [NOT APPROVED | APPROVED WITH FIXES | APPROVED]

### Scores
| Chunk | Category | Score |
|-------|----------|-------|
| chunk-1 | correctness | 92 |
| chunk-1 | error-handling | 78 |

### Findings
| File | Line | Severity | Category | Description | Suggestion |
|------|------|----------|----------|-------------|------------|
| run.sh | 23 | critical | error-handling | ... | ... |
```

## When to use this skill

- Replace both "spec compliance review" and "code quality review" steps in subagent-driven-development
- The assessor's `spec-compliance` custom category handles spec checking
- Run once per task after the implementer commits
- If NOT APPROVED: same implementer fixes, then re-run this full skill

## Red flags

- Never dispatch reviewers before the assessor returns (categories must be known first)
- Never dispatch reviewers sequentially — they are independent and must run in parallel
- Never skip aggregation — a score of 78 on a critical category is a major finding even if no individual finding is marked critical
````

**Step 3: Verify file exists**

```bash
ls -la ~/claude-code-skills/skills/orchestrated-review/SKILL.md
head -10 ~/claude-code-skills/skills/orchestrated-review/SKILL.md
```

Expected: file exists, first line is `---` (YAML frontmatter)

**Step 4: Commit**

```bash
cd ~/claude-code-skills
git add skills/orchestrated-review/SKILL.md
git commit -m "feat(skills): add orchestrated-review — category-driven parallel review skill"
```

---

### Task 2: Wire the skill via Home Manager symlink

The skill needs to be symlinked into `~/.claude/skills/` so Claude Code can find it.
Check how existing skills are wired, then add the new one.

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/skills.nix`

**Step 1: Read skills.nix to understand the pattern**

```bash
cat ~/nixos-config/modules/programs/cli/claude-code/skills.nix
```

Look for how existing skills from the `skillsSrc` are symlinked. The pattern is typically:
```nix
".claude/skills/<name>" = {
  source = "${skillsSrc}/skills/<name>";
  recursive = true;
};
```
or similar.

**Step 2: Add orchestrated-review entry**

Following the exact same pattern as existing skill entries, add:
```nix
".claude/skills/orchestrated-review" = {
  source = "${skillsSrc}/skills/orchestrated-review";
  recursive = true;
};
```

(Adjust to match the exact syntax used in the file.)

**Step 3: Verify the edit looks correct**

```bash
grep -A3 "orchestrated-review\|clean-code-principles" ~/nixos-config/modules/programs/cli/claude-code/skills.nix
```

Expected: both entries present, same format.

**Step 4: Commit**

```bash
cd ~/nixos-config
git add modules/programs/cli/claude-code/skills.nix
git commit -m "feat(claude-code): wire orchestrated-review skill via Home Manager"
```

---

### Task 3: Activate via Home Manager and verify

**Step 1: Run Home Manager switch**

```bash
home-manager switch --flake ~/nixos-config#lukas 2>&1 | tail -20
```

Expected: completes without error

**Step 2: Verify symlink exists**

```bash
ls -la ~/.claude/skills/orchestrated-review/
```

Expected: `SKILL.md` present in the symlinked directory

**Step 3: Verify skill is discoverable**

```bash
head -5 ~/.claude/skills/orchestrated-review/SKILL.md
```

Expected: YAML frontmatter with `name: orchestrated-review`

**Step 4: Push both repos**

```bash
cd ~/claude-code-skills && git push origin main
cd ~/nixos-config && git push origin homelab
```

Report: push output for both repos.
