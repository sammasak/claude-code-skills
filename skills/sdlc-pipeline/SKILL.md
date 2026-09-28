---
name: sdlc-pipeline
description: "Use to drive the sdlc:* stage machine in a repo whose devenv defines platform.sdlc (rust preset: sketch -> model -> test -> review -> perf -> security -> done). Walks the pipeline by running devenv tasks run sdlc:done, dispatching the agent for the first failing stage, and looping until green."
allowed-tools: Bash, Read
injectable: true
---

# SDLC Pipeline Walker

Drives a devenv-generated SDLC stage machine (`platform.sdlc`) to green. The walker itself
tracks no session state; devenv's on-disk guard and verdict stamps are the only state, and
re-running `sdlc:done` always reflects them. There is nothing to resume or track between
loop iterations except "run it again."

## The Loop

1. Run `devenv tasks run sdlc:done`.
2. All green: report pipeline complete. The done-bar is met by construction, no separate check needed.
3. Else: the first failing wrapper's name identifies the stage and guard (`sdlc:<stage>-<sanitized-guard>`, or `sdlc:<stage>-verdict` for a review stage). Dispatch that stage's agent as a subagent. The brief is: the failing guard's output, the stage's job description (table below), and the repo's rubric doc for a review stage.
4. Review stage: the dispatched reviewer follows the `orchestrated-review` skill and writes the verdict file (see below) instead of editing code.
5. Goto 1.

## Rules

- **Agents never self-certify.** A stage passes only when its guard tasks exit 0; never take a dispatched agent's own word that a stage is done. That's the whole point of the machine.
- **Never push past a red `sdlc:done`.** Re-run the loop until green before `git push`.
- **Single pipeline at a time, per checkout.** State derives from the working tree, so two pipelines running concurrently in the same checkout will stamp over each other's fingerprints. Don't parallelize this loop.
- Any working-tree change invalidates every stamp by design. That's re-verification, not a bug. Don't be surprised when a fix to stage N causes stage N-1's guard to re-run too.
- Stage order and which stages exist are per-repo config (`platform.sdlc.stages`, preset-dependent). Don't assume the rust table below applies to a non-rust preset.

## Stage Briefs (rust preset)

| Stage | Agent's job | Guards |
|---|---|---|
| sketch | Type-model ideation: signatures, sum types, newtypes first. `todo!()` bodies are fine. | `rust:check`, `rust:clippy-soft` |
| model | Harden: real bodies, strict lint gate clean. | `rust:lint`, `rust:fmt-check` |
| test | Pillar-2 tests (nextest + doctests, property/snapshot where it fits). | `rust:test` |
| review | Qualitative pass against the repo's rubric: illegal-states-unrepresentable, parse-don't-validate, correctness. Repo rubric doc varies, e.g. `docs/PILLARS.md`, or karta's `workflows/quality-audit.js`; check the target repo. | verdict stage |
| perf | Hold budgets, explain regressions. | `rust:criterion`, `rust:bloat` |
| security | Supply chain and advisories clean. | `rust:audit` |
| done | Umbrella only, nothing to do. | none |

## Verdict Stages

A `verdict = true` stage's guard can't produce judgment itself, its `exec` just fails with
"stage `<s>` requires an agent review verdict." The dispatched reviewer produces the
judgment by writing `$DEVENV_STATE/sdlc/verdict-<stage>.json`:

```json
{ "fingerprint": "<output of sdlc-fingerprint>", "grade": 1-10, "findings": [ ... ] }
```

`sdlc-fingerprint` is on PATH inside the devenv shell, run it, don't hand-compute the
fingerprint. The guard then passes when the recorded fingerprint matches the current tree
and `grade >= platform.sdlc.bar`. Because the fingerprint covers the working tree, any
further code change (including a fix made after a low grade) invalidates the verdict
automatically, no separate cleanup step needed.
