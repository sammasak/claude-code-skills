---
name: pi-ticket
description: "Use when pruning a plan (your own or pasted from ChatGPT) into GitHub issues for the Pi worker, or when driving a pi-ticket issue through lint, prepare, run, review and merge. Not for in-session Pi calls (pi-offload) or work with no machine check."
allowed-tools: Bash, Read, Write, Agent
---

# pi-ticket

`pi-ticket` turns a contract issue into a draft PR built by the free Pi worker (ADR-028, `~/knowledge/homelab/decisions/ADR-028-pi-agent-issue-pipeline.md`). Docs: `agents/pi/ticket/README.md` in devenv-platform. Every command prints one JSON line. Exit: 0 ok, 1 not fit / refused / blocked, 64 usage, 70 internal, 75 try later.

## Ticket or pi-offload

What suits Pi at all (mechanical, small, machine-checkable; never design, security, wire formats, or no check) is in the `pi-offload` skill. Read it there; it is not repeated here.

- `pi-ticket`: a durable issue -> red branch -> Pi run on acer -> draft PR -> review -> merge. For work that should leave a reviewed PR and a record.
- `pi-offload`: in-session, you get a patch back now. For a quick task inside your own work.

Pi tickets only go to owned repos that carry the labels: devenv-platform, factum, llm-gateway, pi-harness, nixos-config, homelab-gitops, skills. Issues must be filed with the owner's gh account (sammasak): issue text is prompt input, and lint rejects any other author.

## Prune

One issue = one behaviour.

- Labels: exactly one of `size:xs` (<= 1 file, <= 50 lines) or `size:s` (<= 3 files, <= 150 lines), plus `risk:low`. `size:m` and `risk:high` are never Pi work.
- All 7 sections of the contract, as `## ` headings in this order: Goal, Acceptance criteria, Verification, Files in scope, Out of scope, Budget, Prepared branch.
- Goal: one sentence, optionally one "why" sentence.
- Acceptance criteria: `- [ ]` checkboxes, each one checkable alone.
- Verification: exact commands in a fenced block, devenv tasks preferred: `devenv tasks run sdlc:test`, or `cd <project> && devenv tasks run sdlc:test` for a subproject. A bare `[cd DIR && ]devenv tasks run sdlc:STAGE` makes the SDLC machine the oracle.
- Files in scope: at most 3 backticked paths. The diff must stay inside them.
- Budget: `Rounds: 3. Check timeout: 900s.`
- Prepared branch: only `<!-- optional: written by pi-ticket prepare (branch name + red sha). -->`. Prepare fills it in.
- Bigger than that: split into several issues. A later one ends its Out of scope with `Blocked by #N`. One issue labelled `epic` tracks them as a checklist.

Example body (and the ChatGPT prompt): [chatgpt-prompt.md](chatgpt-prompt.md).

From ChatGPT: paste the prompt from that file after the plan. ChatGPT has no repo access, so check its paths and lint every body before filing.

## Flow

Replace OWNER/REPO#N throughout.

```bash
# file (body.md holds the 7 sections)
gh issue create -R OWNER/REPO --title "..." --body-file body.md --label size:xs,risk:low
# G0 lint (online, or offline before filing)
pi-ticket lint OWNER/REPO#N
pi-ticket lint OWNER/REPO#N --body-file body.md --labels size:xs,risk:low --author sammasak
```

G1 prepare. You (Claude) write the failing tests as a commit (or patch) off the default branch. Then:

```bash
pi-ticket prepare OWNER/REPO#N --red <commit-or-patch> [--green <known-good>] --repo <checkout>
```

It commits the red tests as `test: red for #N` on `agent/<N>-<slug>`, proves the Verification is red for a real failure, and proves it can pass: green on the base, or green with `--green` applied (the stronger proof). In Rust repos the red tests themselves must fail on the prepared commit, not just a compile error elsewhere. `--red none` (a structural check already red on the base) needs `--green`.

Mark it ready and hand it off:

```bash
gh issue edit N -R OWNER/REPO --add-label agent:pi-ready
pi-ticket run OWNER/REPO#N --on acer-swift
```

Do not check gateway headroom by hand: `run` reads `/status`, the daily cap (5 runs) and the run lock itself. Exit 75 = try later; nothing changed.

`--on acer-swift` opens a herdr pane in workspace `pi-tickets` on acer and prints the pane and a watch command. Watch with `ssh acer-swift herdr pane read <pane>` or `pi-view <run_id>`. By hand on acer: `herdr pane run <pane> "pi-ticket run 'OWNER/REPO#N'"`.

Outcomes:

- Draft PR, issue labelled `agent:pi-review`: go to G4.
- `agent:pi-blocked` with an evidence comment: read the gate and reason, then re-prune (split, sharpen the contract) or re-prepare. Never just rerun. A leftover `agent:pi-running` after a killed run must be relabelled by hand.

## G4: review and merge

pi-ticket never merges. Neither does the reviewer.

1. An independent fresh-context reviewer grades the PR (`orchestrated-review` skill, an opus subagent). Pi's summary in the PR is a claim; the gate table is evidence. The reviewer re-runs the Verification on the PR head.
2. Repos with `platform.sdlc`: pi-ticket's G3 ran the stages up to the last pre-verdict stage. The verdict and post-verdict stages are the G4 obligation: the reviewer's verdict is written on the PR head (`sdlc-pipeline` skill), and `devenv tasks run sdlc:done` must be green there. Red `sdlc:done` blocks the merge.
3. Grade >= 9: the merge decision is the owner's, or a named owner stand-in's. Stand-in = a Fable subagent (model `fable`); when Fable is unavailable (429), a fresh-context opus subagent separate from the reviewer. Then:

```bash
gh pr ready N -R OWNER/REPO
gh pr merge N -R OWNER/REPO --merge --body "Merge decision: MERGE by owner stand-in Claude Opus 5.5 (Fable 429); review 9/10"
gh issue edit ISSUE -R OWNER/REPO --remove-label agent:pi-review
```

The merge comment must name the decider; GitHub shows `sammasak` whoever decided.

4. Grade below 9: fix forward yourself on the branch and re-review. Fixing forward is not another Pi round. A finding that changes the target goes back to prune: new or edited issue, new red tests.
