---
name: sdlc-pipeline
description: "Use to drive the sdlc:* stage machine in a repo whose devenv defines platform.sdlc (rust preset stages: sketch -> model -> test -> review -> perf -> security; sdlc:done is the aggregate task)."
allowed-tools: Bash, Read, Edit, Write, Task
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
   `devenv shell -q --` fallback above if not already inside one). This reports stage state,
   the last-red tail if any, the current stage's brief, and standing verdict findings. It
   prints exact plan/rubric paths only when the current stage is a verdict stage; otherwise
   read the verdict stage's `plans[]` and `rubrics[]` from `$SDLC_MACHINE` when it is reached.
2. Run `devenv tasks run sdlc:done`.
3. All green: report that every configured stage passed. Before calling the project done, compare the configured graph and bar with the project's documented completion criteria; disclose any criteria absent from the graph.
4. Else: the first failing wrapper's name identifies the stage and guard (`sdlc:<stage>-<sanitized-guard>`, or `sdlc:<stage>-verdict` for a review stage). Dispatch a fresh subagent for that stage. For a review stage, compose its brief from the stage brief, exact `plans[]` and `rubrics[]` in `$SDLC_MACHINE`, the complete change range, and deterministic-check evidence. Never guess a plan or rubric path. If `plans[]` is empty, tell the reviewer that no plan was configured.
5. A guard-stage agent proposes/implements only work in its scope. A review agent follows `orchestrated-review`, returns findings and category scores, and does not edit implementation files or write verdict files. Record the fingerprint before dispatch and again after the review; discard the result and restart review if they differ.
6. Route the review decision before rerunning `sdlc:done`:
   - `approved`: only when the reviewer outcome is `APPROVED`, every category score is at least `10 * platform.sdlc.bar`, and there are no critical or major findings. Map the minimum category score to the 1–10 gate grade with `max(1, min(10, floor(score / 10)))`. If the reviewer says `APPROVED` but the scores miss the bar-derived threshold, record `revise` with that reason; do not silently approve. The walker writes the verdict from the review result and reruns the task graph. Continue only if the gate accepts it.
   - `revise`: send bounded findings back to a fresh implementation context without changing the plan. Run affected checks, then obtain a fresh review.
   - `replan`: if findings show a wrong assumption, missing behavior, or changed acceptance criterion, dispatch a fresh planning context with configured plan documents, findings, new evidence, and candidate tests. Before routing, ensure the memo identifies the affected plan section, revised behavior, evidence, candidate acceptance tests, risk/scope impact, and any user decision; ask the reviewer for a supplement if required details are absent. Propose plan/test changes first; ask the user to approve material scope or acceptance changes before implementation. Then implement, rerun checks, and review the new fingerprint.
   - `needs-human`: stop and present evidence plus one focused question.
   Map `APPROVED WITH FIXES` and `NOT APPROVED` according to the findings: use `replan` when a finding invalidates a plan assumption, omits required behavior, changes acceptance criteria, or requires new tests/behavior; otherwise use `revise` for bounded implementation corrections within the approved plan. Unresolved high-impact judgment maps to `needs-human`. Before routing to `replan`, ensure the memo identifies the affected plan section, revised behavior, evidence, candidate acceptance tests, risk/scope impact, and any user decision; request a reviewer supplement if details are missing. For non-approved decisions, the walker writes a non-passing memo; the task graph does not route them.
7. Never reuse an approval after a code, plan, rubric, or configuration change. Repeat the loop with a fresh reviewer until green or a human decision is required.
8. Limit one uninterrupted walker invocation to three `revise`/`replan` cycles. Before a fourth, stop unattended work, preserve the current non-passing memo and evidence, and escalate with a concise summary and one decision question. This is a skill-level policy, not a module-enforced limit; only resume after an explicit human direction.

## Reading the Machine

Stage order and briefs are no longer hardcoded here; they live in the repo's own machine, rendered at devenv eval and exposed as `$SDLC_MACHINE` (a JSON file path). Before relying on its contents, reject any unsupported schema version:

```sh
devenv shell -q -- sh -c 'jq -e ".schemaVersion == 1" "$SDLC_MACHINE" >/dev/null'
```

If this check fails, stop and report the observed version; do not infer or silently accept a different schema. The current machine contract is version 1. Additive fields retain that version; changing or removing existing fields requires a new version and a compatible walker update.

```json
{ "schemaVersion": 1, "name": "<repo>", "bar": 9, "order": ["sketch", "..."], "terminal": ["..."],
  "stages": { "<name>": { "after": [], "guards": [], "verdict": false,
      "plans": ["/nix/store/...-plan.md"],
      "rubrics": ["/nix/store/...-SDLC-REVIEW.md"],
      "brief": "...", "wrappers": ["sdlc:<s>-<g>", "..."] } } }
```

When already inside `devenv shell`, read the machine directly. For a one-shot/non-interactive shell, keep the variable access inside the shell and capture the JSON output:

```sh
machine_json="$(devenv shell -q -- sh -c 'cat "$SDLC_MACHINE"')"
```

Read a stage's brief with jq inside the devenv shell, don't guess it:

```sh
devenv shell -q -- sh -c 'jq -r ".stages.review.brief" "$SDLC_MACHINE"'
```

`order` is the topological stage order for the current repo's preset (deps first); `stages.<name>.verdict` marks review-style stages. Briefs, plan paths, and rubric paths are consumer-overridable, so always read `$SDLC_MACHINE` rather than assuming rust-preset defaults apply. The Nix store paths identify immutable review inputs; read every listed plan and rubric before reviewing.

## Review Range

Before dispatching a reviewer, establish the base revision. For a pull request,
use the target branch merge-base; for local work, use the base named by the
task or project. Include commits from base to `HEAD`, staged and unstaged
changes from `HEAD`, and the contents of non-ignored untracked files. If no
trustworthy base is available, ask before approving; a clean worktree diff is
not proof that there are no committed changes to review.

## Rules

- **Agents cannot certify a stale tree.** A stage passes only when its guard tasks exit 0 against the current fingerprint; never take a dispatched agent's own word that a stage is done. Review independence is an orchestration convention -- this walker dispatches the review stage to a separate subagent -- not an enforcement mechanism the machine itself checks.
- **Never push past a red `sdlc:done`.** Re-run the loop until green before `git push`.
- **Single pipeline at a time, per checkout.** State derives from the working tree, so two pipelines running concurrently in the same checkout will stamp over each other's fingerprints. Don't parallelize this loop.
- Any working-tree change invalidates every stamp by design. That's re-verification, not a bug. Don't be surprised when a fix to stage N causes stage N-1's guard to re-run too.
- Stage order and which stages exist are per-repo config (`platform.sdlc.stages`, preset-dependent). Read `$SDLC_MACHINE`, don't assume the rust preset applies to a non-rust repo.
- `sdlc-status` is read-only (never writes stamps, never runs guards) and already accounts for staleness: it only reports a stage red when `last-red.json`'s fingerprint matches the current tree, otherwise a stale red demotes to unverified. Trust its state, don't recompute freshness by hand.

## Verdict Stages

A `verdict = true` stage's guard can't produce judgment itself, its `exec` just fails with
"stage `<s>` requires an agent review verdict." The review workflow returns
specialist category results; its controller determines the aggregate outcome.
The walker maps that outcome and findings, then alone writes
`$DEVENV_STATE/sdlc/verdict-<stage>.json`, after confirming the fingerprint did not change
during review:

```json
{ "fingerprint": "<output of sdlc-fingerprint>", "stage": "<stage>",
  "decision": "approved", "grade": 9, "rationale": "Every category meets the configured bar.",
  "findings": [] }
```

`decision` is one of `approved`, `revise`, `replan`, or `needs-human`; `grade` is an
integer from 1 to 10. Use the actual decision and numeric grade in the JSON.

`sdlc-fingerprint` is on PATH inside the devenv shell, run it; don't hand-compute the
fingerprint. The task gate accepts only `decision: "approved"`, the matching stage and
fingerprint, a non-empty rationale, a findings array, and an integer grade in 1–10 at or
above `platform.sdlc.bar`. Other decisions are persisted as non-passing review memos for the
walker to route; they deliberately keep `sdlc:done` red. After any code, plan, rubric, or
configuration change, obtain a fresh review against the new fingerprint.
