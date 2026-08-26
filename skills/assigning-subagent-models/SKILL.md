---
name: assigning-subagent-models
description: "Use when building, creating, or editing a multi-agent workflow (the Workflow JS harness with agent()/pipeline()/parallel()) or dispatching any subagent via the Agent tool or .claude/agents/*.md — every subagent must be given an explicit model chosen by effort tier, never left to inherit."
injectable: true
---

Use when building, creating, or editing a multi-agent workflow (the Workflow JS harness with agent()/pipeline()/parallel()) or dispatching any subagent via the Agent tool or .claude/agents/*.md — every subagent must be given an explicit model chosen by effort tier, never left to inherit.

# assigning-subagent-models

## Overview

**Every subagent you spawn gets an explicit model. No exceptions.** An `agent()` call, an `Agent`-tool dispatch, a `pipeline`/`parallel` stage, a `.claude/agents/*.md` definition — each one names a model, chosen from the effort ladder below.

**Why the rule is absolute:** a spawn with no model *silently inherits the main-loop model*. That inheritance is invisible in the code, unpredictable at runtime, and defeats the entire point of orchestration — matching model strength to task effort. A missing model is a defect, not a default.

**Violating the letter of this rule is violating its spirit.** "It'll inherit something reasonable" is the failure, not the workaround for it.

## When to Use

- Authoring or editing a `Workflow` script — every `agent()` call, including those inside `pipeline()` / `parallel()` stages.
- Dispatching a one-off subagent with the `Agent` tool.
- Writing or editing a `.claude/agents/<name>.md` subagent definition.
- Reviewing any of the above — a spawn without an explicit model is a review blocker.

## The Effort Ladder

Pick the tier by the **cost of being wrong** and the **kind of thinking** required. Pinned IDs are the source of truth for *which model and why*; the alias is the literal token you pass at a surface that only accepts aliases (see Surfaces below).

| Tier | Pinned ID | Alias | Use for |
|------|-----------|-------|---------|
| **Author / plan** | `claude-fable-5` or `claude-opus-4-8` | `fable` / `opus` | Designing, creating, or editing the workflow itself; top-tier reasoning and architecture. This is the model *you* run as while authoring. |
| **Hard** | `claude-opus-4-8` | `opus` | Fact-checking, implementation, adversarial verification, synthesis, judging, decisions — anything where a wrong answer is costly. |
| **Light** | `claude-sonnet-4-6` | `sonnet` | Research, information gathering, search fan-out, summarization, first-pass drafting. |
| **Trivial** | `claude-haiku-4-5` | `haiku` | Mechanical work: lint/format, simple greps, boilerplate transforms, rote extraction. |

**Heuristic:** *research / gather → Sonnet. verify / implement / decide → Opus. design the whole thing → Fable or Opus. pure mechanical → Haiku.*

**When torn between two tiers, pick the harder one.** Under-powering a verification or implementation agent is the expensive mistake; over-powering a grep is cheap by comparison.

## Surfaces: which token to pass where

The pinned ID names intent; the surface decides the literal token. Always keep the pinned ID visible (in a comment) even where you must pass an alias, so the *why* survives.

| Surface | Accepts | Pass |
|---------|---------|------|
| `.claude/agents/*.md` frontmatter `model:` | Pinned ID | `model: claude-opus-4-8` |
| CLI `--model` flag | Pinned ID | `--model claude-opus-4-8` |
| `Agent` tool `model` parameter | **Alias only** | `model: 'opus'  // claude-opus-4-8` |
| `Workflow` `agent()` / phase `model` opt | Alias | `{ model: 'opus', ... }  // claude-opus-4-8` |

## Example — a Workflow with a model on every spawn

```javascript
// Research fans out on the LIGHT tier; verification and synthesis are HARD.
const research = await pipeline(
  CANDIDATES,
  (lib) => agent(`Research the library "${lib}" from primary sources.`,
    { model: 'sonnet', label: `research:${lib}`, schema: RESEARCH }),  // claude-sonnet-4-6 — gathering
)

const design = await agent('Synthesize a recommendation from the research.',
  { model: 'opus', label: 'design', schema: DESIGN })                  // claude-opus-4-8 — decision

const impl = await agent('Implement the chosen integration.',
  { model: 'opus', label: 'implement', schema: IMPL })                 // claude-opus-4-8 — costly if wrong

const lint = await agent('Run the formatter and report warnings.',
  { model: 'haiku', label: 'lint' })                                   // claude-haiku-4-5 — mechanical
```

## Example — an Agent-tool dispatch and an agent definition

```
// Agent tool — the model field is REQUIRED, alias only:
Agent({ subagent_type: 'general-purpose', model: 'sonnet', /* claude-sonnet-4-6 */
        description: 'Gather API docs', prompt: '...' })
```

```yaml
# .claude/agents/verifier.md — pinned ID in frontmatter:
---
name: verifier
model: claude-opus-4-8   # hard tier: fact-checking is costly if wrong
---
```

## Common Mistakes

- **Omitting the model to "keep it simple."** The spawn then inherits the main-loop model invisibly. Simplicity is naming the model, not hiding it.
- **Modeling the `agent()` calls but forgetting the standalone `Agent`-tool dispatch** (or the final summary/lint step). *Every* spawn, including the last one, gets a model.
- **Passing a pinned ID to the `Agent` tool's `model` param.** It rejects `claude-opus-4-8` — pass `opus` and put the pinned ID in a comment.
- **Defaulting everything to `opus` "to be safe."** Research and gathering fan-outs are the bulk of most workflows; running them on Opus burns budget for no quality gain. Match the tier.
- **Guessing model IDs from memory.** Use the ladder above; the IDs there are current.

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "It'll inherit a sensible model." | Inheritance is invisible and unpredictable. That IS the defect. Name it. |
| "This agent is trivial, the model doesn't matter." | Then it's a one-word decision: `haiku`. Trivial ≠ omit. |
| "I'll add models once the structure works." | The structure isn't done until every spawn names a model. Add it now. |
| "I'm not sure the harness accepts model opts." | It does. Aliases at the tool/`agent()` surface, pinned IDs in frontmatter/`--model`. See Surfaces. |
| "The main-loop model is fine for all of them." | Then you wrote a pipeline that pays Opus rates for grep work, or Haiku rates for verification. Match the tier. |
| "Just this one dispatch can inherit." | One unnamed spawn is one silent defect. No spawn is exempt. |

## Red Flags — STOP

- An `agent()`, `parallel()`, or `pipeline()` stage with opts but **no `model` key**.
- An `Agent`-tool dispatch with `subagent_type` / `description` but **no `model`**.
- A `.claude/agents/*.md` with no `model:` line.
- The phrase "it'll default to…" or "inherits the…" in your reasoning about a spawn.
- A workflow where **every** agent runs the same tier — you almost certainly skipped the effort-matching step.

**All of these mean: assign the explicit model now, from the ladder, before the workflow is done.**
