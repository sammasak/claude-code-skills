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

## Prerequisites

This skill assumes a `devenv shell` for the target repo, with the platform module (the one
defining `platform.sdlc`) enabled, and `jq` available. `sdlc-status` and `$SDLC_MACHINE` are
shell-scoped: they only exist inside that devenv shell (`sdlc-status` is a package the
platform module puts on PATH; `$SDLC_MACHINE` is an env var it sets), not on a bare host
shell or in an agent session that never entered the devenv environment.

If the session is not already inside the devenv shell (no direnv, or a non-interactive agent
invocation), fall back to `devenv shell -q -- sdlc-status --context` (and likewise prefix any
other `sdlc-status`/`devenv tasks run` call with `devenv shell -q --`) rather than assuming
the tools are on PATH.

## The Loop

1. Start the walk with `sdlc-status --context` (on PATH in the devenv shell; use the
   `devenv shell -q --` fallback above if not already inside one). This output IS the walk's
   opening brief: state per stage, the last-red tail if any, the current stage's brief, and
   standing verdict findings with freshness marks.
2. Run `devenv tasks run sdlc:done`.
3. All green: report pipeline complete. The done-bar is met by construction, no separate check needed.
4. Else: the first failing wrapper's name identifies the stage and guard (`sdlc:<stage>-<sanitized-guard>`, or `sdlc:<stage>-verdict` for a review stage). Dispatch a subagent for that stage. The stage-to-agent convention is: the stage name IS the agent role (there is no separate agent registry mapping stage names to roles). The walker composes that dispatch's brief itself from the stage's own machine.json data: the failing guard's output, the stage's `brief` field (read from `$SDLC_MACHINE`, see below), and the repo's rubric doc for a review stage.
5. Review stage: the dispatched reviewer follows the `orchestrated-review` skill and writes the verdict file (see below) instead of editing code.
6. Goto 2.

## Reading the Machine

Stage order and briefs are no longer hardcoded here; they live in the repo's own machine, rendered at devenv eval and exposed as `$SDLC_MACHINE` (a JSON file path):

```json
{ "name": "<repo>", "bar": 9, "order": ["sketch", "..."], "terminal": ["..."],
  "stages": { "<name>": { "after": [], "guards": [], "verdict": false,
      "brief": "...", "wrappers": ["sdlc:<s>-<g>", "..."] } } }
```

Read a stage's brief with jq, don't guess it:

```sh
jq -r '.stages["<stage>"].brief' "$SDLC_MACHINE"
```

`order` is the topological stage order for the current repo's preset (deps first); `stages.<name>.verdict` marks review-style stages. Briefs are consumer-overridable per repo (e.g. karta ships its own wording for some stages), so always read `$SDLC_MACHINE` rather than assuming rust-preset defaults apply. A review stage's rubric doc isn't part of machine.json; check the target repo, e.g. `docs/PILLARS.md`, or karta's `workflows/quality-audit.js` as an example.

## Rules

- **Agents cannot certify a stale tree.** A stage passes only when its guard tasks exit 0 against the current fingerprint; never take a dispatched agent's own word that a stage is done. Review independence is an orchestration convention -- this walker dispatches the review stage to a separate subagent -- not an enforcement mechanism the machine itself checks.
- **Never push past a red `sdlc:done`.** Re-run the loop until green before `git push`.
- **Single pipeline at a time, per checkout.** State derives from the working tree, so two pipelines running concurrently in the same checkout will stamp over each other's fingerprints. Don't parallelize this loop.
- Any working-tree change invalidates every stamp by design. That's re-verification, not a bug. Don't be surprised when a fix to stage N causes stage N-1's guard to re-run too.
- Stage order and which stages exist are per-repo config (`platform.sdlc.stages`, preset-dependent). Read `$SDLC_MACHINE`, don't assume the rust preset applies to a non-rust repo.
- `sdlc-status` is read-only (never writes stamps, never runs guards) and already accounts for staleness: it only reports a stage red when `last-red.json`'s fingerprint matches the current tree, otherwise a stale red demotes to unverified. Trust its state, don't recompute freshness by hand.

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
